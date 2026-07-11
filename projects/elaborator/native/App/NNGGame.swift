import Foundation

// MARK: - nng-levels.json model (produced by scripts/nng-extract.py)

struct NNGDocEntry: Decodable, Hashable {
  let displayName: String?
  let category: String?
  let content: String
}

struct NNGHintInfo: Decodable, Hashable {
  let text: String
  let hidden: Bool
}

private struct NNGLevelJSON: Decodable {
  let module: String
  let level: Int
  let title: String
  let statementName: String?
  let statementSig: String
  let statementDoc: String
  let introduction: String
  let conclusion: String
  let preamble: [String]
  let hints: [NNGHintInfo]
  let newTactics: [String]
  /// Tactics usable from this level on but kept out of the inventory display
  /// (upstream `NewHiddenTactic`, e.g. `nth_rewrite` at Tutorial L02).
  let newHiddenTactics: [String]
  let newTheorems: [String]
  let newDefinitions: [String]
  let disabledTactics: [String]
}

private struct NNGWorldJSON: Decodable {
  let id: String
  let title: String
  let introduction: String
  let levels: [NNGLevelJSON]
}

private struct NNGGameJSON: Decodable {
  let worlds: [NNGWorldJSON]
  let docs: [String: [String: NNGDocEntry]]
}

/// Per-level payload carried on `Exercise` for NNG levels.
struct NNGLevelInfo: Hashable {
  let worldTitle: String
  let levelNumber: Int
  let levelCount: Int
  /// Bare name of the theorem this level proves (nil for unnamed statements).
  /// The proof UI refuses tactics that mention it: with the shared
  /// `import Game` header the theorem already exists in the environment, so
  /// `exact zero_add ..` would close the goal by cheating.
  let statementName: String?
  let introduction: String
  let conclusion: String
  let statementDoc: String
  let hints: [NNGHintInfo]
  /// Unlocked tactics, newest first.
  let tactics: [String]
  /// Unlocked theorems (bare names, newest first), excluding this level's own.
  let theorems: [String]
}

// MARK: - Completion persistence

enum NNGProgress {
  static let key = "nngCompletedLevels"

  static func completed() -> Set<String> {
    let raw = UserDefaults.standard.string(forKey: key) ?? ""
    return Set(raw.split(separator: ",").map(String.init))
  }

  static func markComplete(_ id: String) {
    var ids = completed()
    guard !ids.contains(id) else { return }
    ids.insert(id)
    UserDefaults.standard.set(ids.sorted().joined(separator: ","), forKey: key)
  }
}

// MARK: - Store

private func bareName(_ n: String) -> String {
  n.split(separator: ".").last.map(String.init) ?? n
}

/// Loads `nng-levels.json` from the app bundle once and exposes the NNG
/// worlds as `WorldGroup`s of `Exercise`s (same shapes the rest of the UI
/// uses), plus the inventory documentation tables.
final class NNGGameStore {
  static let shared = NNGGameStore()

  let worldGroups: [WorldGroup]
  /// World title -> world introduction prose.
  let worldIntros: [String: String]
  /// Bare theorem name -> doc entry.
  let theoremDocs: [String: NNGDocEntry]
  /// Tactic name -> doc entry.
  let tacticDocs: [String: NNGDocEntry]

  private init() {
    guard let url = Bundle.main.url(forResource: "nng-levels", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let game = try? JSONDecoder().decode(NNGGameJSON.self, from: data)
    else {
      worldGroups = []
      worldIntros = [:]
      theoremDocs = [:]
      tacticDocs = [:]
      return
    }

    var thmDocs: [String: NNGDocEntry] = [:]
    for (name, doc) in game.docs["TheoremDoc"] ?? [:] {
      thmDocs[bareName(name)] = doc
    }
    var tacDocs: [String: NNGDocEntry] = [:]
    for (name, doc) in game.docs["TacticDoc"] ?? [:] {
      tacDocs[bareName(name)] = doc
    }

    var groups: [WorldGroup] = []
    var intros: [String: String] = [:]
    var tactics: [String] = []  // accumulated across worlds, oldest first
    var inventory: [String] = []  // accumulated theorems, oldest first
    for world in game.worlds {
      intros[world.title] = world.introduction
      var exs: [Exercise] = []
      for lvl in world.levels {
        for t in lvl.newTactics where !tactics.contains(t) {
          tactics.append(t)
        }
        for thm in lvl.newTheorems.map(bareName) where !inventory.contains(thm) {
          inventory.append(thm)
        }
        let own = lvl.statementName
        let prelude = "import Game\n\n" + lvl.preamble.joined(separator: "\n") + "\n\n"
        let info = NNGLevelInfo(
          worldTitle: world.title,
          levelNumber: lvl.level,
          levelCount: world.levels.count,
          statementName: own,
          introduction: lvl.introduction,
          conclusion: lvl.conclusion,
          statementDoc: lvl.statementDoc,
          hints: lvl.hints,
          tactics: tactics.reversed(),
          theorems: inventory.filter { $0 != own }.reversed()
        )
        exs.append(
          Exercise(
            id: "nng-\(world.id.lowercased())-l\(String(format: "%02d", lvl.level))",
            title: "L\(String(format: "%02d", lvl.level)): \(lvl.title)",
            world: world.title,
            initialSource: prelude + "example \(lvl.statementSig) := by\n  done\n",
            hiddenPrelude: prelude,
            nng: info
          ))
        // The proved statement joins the inventory for *later* levels.
        if let own, !inventory.contains(own) {
          inventory.append(own)
        }
      }
      groups.append(WorldGroup(world: world.title, exercises: exs))
    }
    worldGroups = groups
    worldIntros = intros
    theoremDocs = thmDocs
    tacticDocs = tacDocs
  }
}
