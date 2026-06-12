import SwiftUI

struct CheckResult: Decodable {
  let diagnostics: [Diagnostic]
  let goals: [Goal]
  let complete: Bool
}

struct Diagnostic: Decodable {
  let line: Int
  let column: Int
  let severity: String
  let message: String
}

struct Goal: Decodable {
  let caseTag: String?
  let hypotheses: [Hypothesis]
  let target: String
}

struct Hypothesis: Decodable {
  let names: [String]
  let type: String
}

enum CheckState {
  case idle
  case ok(CheckResult)
  case bridgeError(String)
}

private enum Palette {
  static let accent = Color(red: 0.96, green: 0.45, blue: 0.16)
  static let accentSoft = Color(
    light: Color(red: 0.99, green: 0.83, blue: 0.69),
    dark: Color(red: 0.45, green: 0.28, blue: 0.16))
  static let keyword = Color(
    light: Color(red: 0.55, green: 0.18, blue: 0.55),
    dark: Color(red: 0.83, green: 0.56, blue: 0.83))
  static let typeBlue = Color(
    light: Color(red: 0.16, green: 0.38, blue: 0.85),
    dark: Color(red: 0.49, green: 0.66, blue: 1.0))
  static let trackDim = Color(.systemGray5)
  static let cardStroke = Color(.systemGray5)
  static let freshPurple = Color(
    light: Color(red: 0.42, green: 0.32, blue: 0.78),
    dark: Color(red: 0.67, green: 0.60, blue: 0.97))
  static let card = Color(.secondarySystemGroupedBackground)
}

struct ExerciseView: View {
  let exercise: Exercise
  @Binding var path: NavigationPath
  @State private var source: String = ""
  @State private var input: String = ""
  @State private var state: CheckState = .idle
  @State private var isRunning = false
  @State private var showingIntro = false
  @State private var showingReference = false

  private static let tactics: [String] = [
    "intro", "intros", "exact", "apply", "rfl",
    "assumption", "cases", "constructor", "left", "right", "have", "refine",
  ]

  var body: some View {
    ZStack {
      Color(.systemGroupedBackground).ignoresSafeArea()
      VStack(spacing: 14) {
        topBar
        progressBar
        ScrollView {
          VStack(spacing: 14) {
            sourceSection
            stateSection
          }
        }
        .frame(maxHeight: .infinity)
        hintRow
        if hasTacticPrefix {
          constantsRow
          freeRow
        } else {
          tacticsRow
        }
        inputRow
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 6)
    }
    .toolbar(.hidden, for: .navigationBar)
    .onAppear {
      if source.isEmpty {
        source = exercise.initialSource
        runCheck()
      }
    }
    .sheet(isPresented: $showingIntro) {
      IntroView(exercise: exercise, mode: .review)
    }
    .sheet(isPresented: $showingReference) {
      TacticReferenceView()
    }
  }

  private var hintRow: some View {
    HStack {
      Spacer()
      Button(action: { showingIntro = true }) {
        HStack(spacing: 5) {
          Image(systemName: "lightbulb")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.accent)
          Text("Stuck? Hint")
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Palette.card)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Palette.cardStroke, lineWidth: 1))
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Top bar

  private var topBar: some View {
    HStack(alignment: .center) {
      Button(action: { path = NavigationPath() }) {
        Image(systemName: "chevron.left")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(.primary)
          .frame(width: 38, height: 38)
          .background(Palette.card)
          .clipShape(Circle())
          .overlay(Circle().stroke(Palette.cardStroke, lineWidth: 1))
      }
      Spacer()
      VStack(spacing: 2) {
        Text(eyebrow)
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .tracking(0.6)
          .foregroundStyle(.secondary)
        Text(displayTitle)
          .font(.system(size: 18, weight: .bold, design: .rounded))
          .foregroundStyle(.primary)
      }
      Spacer()
      HStack(spacing: 8) {
        Button(action: { showingIntro = true }) {
          Image(systemName: "info")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.primary)
            .frame(width: 38, height: 38)
            .background(Palette.card)
            .clipShape(Circle())
            .overlay(Circle().stroke(Palette.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        Button(action: { showingReference = true }) {
          Image(systemName: "rectangle.split.2x1")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 38, height: 38)
            .background(Palette.card)
            .clipShape(Circle())
            .overlay(Circle().stroke(Palette.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var eyebrow: String {
    let chapter = chapterIndex.map { "CH · \($0 + 1)" } ?? "CH"
    return "\(chapter) · \(exercise.world.uppercased())"
  }

  private var displayTitle: String {
    if let colon = exercise.title.firstIndex(of: ":") {
      let lhs = exercise.title[..<colon].trimmingCharacters(in: .whitespaces)
      let rhs = exercise.title[exercise.title.index(after: colon)...].trimmingCharacters(in: .whitespaces)
      return "\(lhs) · \(rhs)"
    }
    return exercise.title
  }

  private var chapterIndex: Int? {
    worldGroups.firstIndex { $0.world == exercise.world }
  }

  private var lessonIndex: Int? {
    worldGroups
      .first { $0.world == exercise.world }?
      .exercises
      .filter { !$0.isWorldIntro }
      .firstIndex(of: exercise)
  }

  private var lessonsInWorld: Int {
    worldGroups
      .first { $0.world == exercise.world }?
      .exercises
      .filter { !$0.isWorldIntro }
      .count ?? 0
  }

  // MARK: - Progress

  private var progressBar: some View {
    let count = max(lessonsInWorld, 1)
    let current = lessonIndex ?? 0
    return HStack(spacing: 6) {
      ForEach(0..<count, id: \.self) { idx in
        Capsule()
          .fill(segmentColor(idx, current: current))
          .frame(height: 6)
      }
    }
  }

  private func segmentColor(_ idx: Int, current: Int) -> Color {
    if idx < current { return Palette.accent }
    if idx == current { return Palette.accentSoft }
    return Palette.trackDim
  }

  // MARK: - Source

  private var sourceSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        sectionLabel("SOURCE")
        Spacer()
        Text("example")
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(.secondary)
      }
      card {
        Text(highlight(displaySource))
          .font(.system(size: 15, design: .monospaced))
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
      }
    }
  }

  private var displaySource: String {
    var s = source
    let donePattern = "  done\n"
    if let range = s.range(of: donePattern, options: .backwards) {
      s.replaceSubrange(range, with: "")
    }
    if s.hasSuffix("\n") { s.removeLast() }
    return s
  }

  // MARK: - State

  private var stateSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        sectionLabel("STATE")
        Spacer()
        stateBadge
      }
      card {
        stateBody
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  @ViewBuilder
  private var stateBadge: some View {
    switch state {
    case .ok(let r) where !r.goals.isEmpty:
      HStack(spacing: 5) {
        Circle().fill(Palette.accent).frame(width: 6, height: 6)
        Text("goal 1 of \(r.goals.count)")
          .font(.system(size: 12, weight: .semibold, design: .monospaced))
          .foregroundStyle(Palette.accent)
      }
    case .ok(let r) where r.complete:
      HStack(spacing: 5) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 11))
          .foregroundStyle(.green)
        Text("complete")
          .font(.system(size: 12, weight: .semibold, design: .monospaced))
          .foregroundStyle(.green)
      }
    default:
      EmptyView()
    }
  }

  @ViewBuilder
  private var stateBody: some View {
    switch state {
    case .idle:
      Text("Loading…")
        .font(.system(size: 13, design: .monospaced))
        .foregroundStyle(.secondary)
    case .bridgeError(let msg):
      Text(msg)
        .font(.system(size: 13, design: .monospaced))
        .foregroundStyle(.red)
        .textSelection(.enabled)
    case .ok(let result):
      if result.complete {
        Text("Proof complete")
          .font(.system(size: 16, weight: .bold, design: .rounded))
          .foregroundStyle(.green)
      } else if let goal = result.goals.first {
        GoalCard(goal: goal)
      } else if result.diagnostics.isEmpty {
        Text("No goal state reached yet.")
          .font(.system(size: 13, design: .monospaced))
          .foregroundStyle(.secondary)
      }
      if !result.diagnostics.isEmpty {
        DiagnosticsView(diagnostics: result.diagnostics)
          .padding(.top, result.goals.isEmpty ? 0 : 10)
      }
    }
  }

  // MARK: - Tactics & constants

  private var tacticsRow: some View {
    HStack(alignment: .center, spacing: 8) {
      Text("TACTICS")
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .tracking(0.6)
        .foregroundStyle(.secondary)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(Self.tactics, id: \.self) { t in
            Button(action: { insert(t) }) {
              Text(t)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Palette.typeBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Palette.card)
                .overlay(Capsule().stroke(Palette.typeBlue.opacity(0.45), lineWidth: 1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var constantsRow: some View {
    HStack(alignment: .center, spacing: 8) {
      Text("CONSTANTS")
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .tracking(0.6)
        .foregroundStyle(.secondary)
      if constants.isEmpty {
        Text("—")
          .font(.system(size: 13, design: .monospaced))
          .foregroundStyle(.secondary)
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(constants, id: \.self) { name in
              Button(action: { insert(name) }) {
                Text(name)
                  .font(.system(size: 14, weight: .semibold, design: .monospaced))
                  .foregroundStyle(Palette.accent)
                  .frame(minWidth: 26)
                  .padding(.horizontal, 9)
                  .padding(.vertical, 5)
                  .background(Palette.accentSoft.opacity(0.6))
                  .clipShape(Capsule())
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var freeRow: some View {
    HStack(alignment: .center, spacing: 8) {
      Text("FREE")
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .tracking(0.6)
        .foregroundStyle(.secondary)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(freshSuggestions, id: \.self) { name in
            Button(action: { insert(name) }) {
              Text(name)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Palette.freshPurple)
                .frame(minWidth: 26)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Palette.freshPurple.opacity(0.12))
                .overlay(Capsule().stroke(Palette.freshPurple.opacity(0.35), lineWidth: 1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private var constants: [String] {
    guard case .ok(let r) = state, let goal = r.goals.first else { return [] }
    return goal.hypotheses.flatMap { $0.names }
  }

  private var freshSuggestions: [String] {
    let inUse = Set(constants)
    let candidates = ["h", "h1", "h2", "x", "y", "z", "p", "q", "n", "m"]
    return candidates.filter { !inUse.contains($0) }
  }

  private var hasTacticPrefix: Bool {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    let firstWord = trimmed.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
    return Self.tactics.contains(firstWord)
  }

  // MARK: - Input

  private var inputRow: some View {
    HStack(spacing: 0) {
      TextField("next tactic", text: $input)
        .textFieldStyle(.plain)
        .font(.system(size: 15, design: .monospaced))
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .submitLabel(.send)
        .onSubmit(send)
        .disabled(isRunning)
        .padding(.leading, 18)
        .padding(.vertical, 14)
      Button(action: send) {
        Text("Run")
          .font(.system(size: 15, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
          .padding(.horizontal, 22)
          .padding(.vertical, 10)
          .background(Palette.accent)
          .clipShape(Capsule())
      }
      .buttonStyle(.plain)
      .disabled(isRunning)
      .opacity(isRunning ? 0.7 : 1.0)
      .padding(.trailing, 6)
    }
    .background(Palette.card)
    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .stroke(Palette.cardStroke, lineWidth: 1)
    )
  }

  // MARK: - Actions

  private func insert(_ token: String) {
    if !input.isEmpty && !input.hasSuffix(" ") {
      input += " "
    }
    input += token + " "
  }

  private func send() {
    let tactic = input.trimmingCharacters(in: .whitespacesAndNewlines)
    if !tactic.isEmpty {
      let donePattern = "  done\n"
      if let range = source.range(of: donePattern, options: .backwards) {
        source.replaceSubrange(range, with: "  \(tactic)\n  done\n")
      } else {
        source.append("  \(tactic)\n")
      }
      input = ""
    }
    runCheck()
  }

  private func runCheck() {
    isRunning = true
    defer { isRunning = false }
    guard let bundleRoot = Bundle.main.bundlePath.cString(using: .utf8),
      let sourceCString = source.cString(using: .utf8),
      let raw = lean_ios_check_source(bundleRoot, sourceCString)
    else {
      state = .bridgeError("Bridge call failed.")
      return
    }
    guard
      let (decoded, _) = String.decodeCString(
        UnsafeRawPointer(raw).assumingMemoryBound(to: UTF8.CodeUnit.self),
        as: UTF8.self
      )
    else {
      state = .bridgeError("Output string decoding failed")
      return
    }
    guard let data = decoded.data(using: .utf8) else {
      state = .bridgeError("UTF8 conversion failed")
      return
    }
    do {
      let result = try JSONDecoder().decode(CheckResult.self, from: data)
      state = .ok(result)
    } catch {
      state = .bridgeError("JSON decode failed: \(error)\nRaw:\n\(decoded)")
    }
  }

  // MARK: - Helpers

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 11, weight: .bold, design: .rounded))
      .tracking(0.8)
      .foregroundStyle(.secondary)
  }

  private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content()
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Palette.card)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(Palette.cardStroke, lineWidth: 1)
      )
  }
}

// MARK: - Syntax highlighting

private let leanKeywords: Set<String> = [
  "example", "theorem", "lemma", "def", "by", "let", "in",
  "match", "with", "if", "then", "else", "fun", "do", "return",
  "where", "show", "from", "have", "suffices",
]

func highlight(_ source: String) -> AttributedString {
  var result = AttributedString()
  var i = source.startIndex
  let identStart: (Character) -> Bool = { $0.isLetter || $0 == "_" }
  let identCont: (Character) -> Bool = { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "'" }
  while i < source.endIndex {
    let ch = source[i]
    if identStart(ch) {
      let start = i
      while i < source.endIndex && identCont(source[i]) {
        i = source.index(after: i)
      }
      let token = String(source[start..<i])
      var piece = AttributedString(token)
      if leanKeywords.contains(token) {
        piece.foregroundColor = Palette.keyword
      } else if let first = token.first, first.isUppercase {
        piece.foregroundColor = Palette.typeBlue
      }
      result.append(piece)
    } else {
      let segStart = i
      while i < source.endIndex && !identStart(source[i]) {
        i = source.index(after: i)
      }
      result.append(AttributedString(String(source[segStart..<i])))
    }
  }
  return result
}

// MARK: - Goal card

private struct GoalCard: View {
  let goal: Goal
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if !goal.hypotheses.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("HYPOTHESES")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(.secondary)
          ForEach(Array(goal.hypotheses.enumerated()), id: \.offset) { _, hyp in
            HStack(alignment: .firstTextBaseline, spacing: 6) {
              Text(hyp.names.joined(separator: " "))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
              Text(":")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.secondary)
              Text(highlight(hyp.type))
                .font(.system(size: 14, design: .monospaced))
                .textSelection(.enabled)
            }
          }
        }
      }
      VStack(alignment: .leading, spacing: 8) {
        Text("SHOW")
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .tracking(0.6)
          .foregroundStyle(.secondary)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Circle().fill(Palette.accent).frame(width: 6, height: 6)
            .alignmentGuide(.firstTextBaseline) { $0.height * 0.5 + 4 }
          Text("⊢")
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(.secondary)
          Text(highlight(goal.target))
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .textSelection(.enabled)
          Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.accentSoft.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Palette.accentSoft.opacity(0.6), lineWidth: 1)
        )
      }
      if let tag = goal.caseTag {
        Text("case \(tag)")
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct DiagnosticsView: View {
  let diagnostics: [Diagnostic]
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("DIAGNOSTICS")
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .tracking(0.6)
        .foregroundStyle(.secondary)
      ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, d in
        VStack(alignment: .leading, spacing: 2) {
          Text("\(d.severity) \(d.line):\(d.column)")
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(d.severity == "error" ? .red : Palette.accent)
          Text(d.message)
            .font(.system(size: 13, design: .monospaced))
            .textSelection(.enabled)
        }
      }
    }
  }
}
