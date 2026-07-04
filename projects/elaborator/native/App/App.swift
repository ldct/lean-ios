import SwiftUI
import UIKit

extension Color {
  /// A dynamic color that resolves per the current light/dark trait.
  init(light: Color, dark: Color) {
    self.init(UIColor { trait in
      trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
    })
  }
}

@main
struct LeanIOSElabExampleApp: App {
  init() {
    NNGTestHarness.runIfRequested()
  }

  var body: some Scene {
    WindowGroup {
      RootView()
    }
  }
}

struct Exercise: Identifiable, Hashable {
  let id: String
  let title: String
  let world: String
  /// Full source handed to the elaborator (includes `hiddenPrelude`).
  let initialSource: String
  var isWorldIntro: Bool = false
  /// Prefix of `initialSource` (imports + namespace) hidden from the SOURCE pane.
  var hiddenPrelude: String = ""
  /// Present iff this is an NNG level loaded from nng-levels.json.
  var nng: NNGLevelInfo? = nil
}

struct ProofPath: Hashable {
  let exercise: Exercise
}

struct WorldGroup: Identifiable {
  let world: String
  let exercises: [Exercise]
  var id: String { world }
}

let exercises: [Exercise] = [
  Exercise(
    id: "typeworld-l01-elements",
    title: "L01: Elements",
    world: "Type World",
    initialSource: "example {A : Type} (a : A) : A := by\n  done\n"
  ),
  Exercise(
    id: "typeworld-l02-proofs",
    title: "L02: Proofs",
    world: "Type World",
    initialSource: "example {P : Prop} (p : P) : P := by\n  done\n"
  ),
  Exercise(
    id: "typeworld-l03-exactelements",
    title: "L03: Exact Elements",
    world: "Type World",
    initialSource: "example {A B : Type} (x : A) (y z : B) : B := by\n  done\n"
  ),
  Exercise(
    id: "typeworld-l04-unittype",
    title: "L04: Unit Type",
    world: "Type World",
    initialSource: "example : Unit := by\n  done\n"
  ),
  Exercise(
    id: "typeworld-l05-typeofpropositions",
    title: "L05: Type Of Propositions",
    world: "Type World",
    initialSource: "example (P Q : Prop) (p : P) : Prop := by\n  done\n"
  ),
  Exercise(
    id: "typeworld-l06-typeoftypes",
    title: "L06: Type Of Types",
    world: "Type World",
    initialSource: "example : Type := by\n  done\n"
  ),
  Exercise(
    id: "typeworld-l07-bosslevel",
    title: "L07: Boss Level",
    world: "Type World",
    initialSource: "example (P Q R : Prop) (q : Q) (r : R) : Type := by\n  done\n"
  ),
  Exercise(
    id: "functionworld-l01-identityfunction",
    title: "L01: Identity Function",
    world: "Function World",
    initialSource: "example {A : Type} : A → A := by\n  done\n"
  ),
  Exercise(
    id: "functionworld-l02-usingfunctions",
    title: "L02: Using Functions",
    world: "Function World",
    initialSource: "example {A B : Type} (a : A) (f : A → B) : B := by\n  done\n"
  ),
  Exercise(
    id: "functionworld-l03-usingfunctionsbackwards",
    title: "L03: Using Functions Backwards",
    world: "Function World",
    initialSource: "example {A B : Type} (a : A) (f : A → B) : B := by\n  done\n"
  ),
  Exercise(
    id: "functionworld-l04-composingfunctions",
    title: "L04: Composing Functions",
    world: "Function World",
    initialSource: "example {A B C : Type} (g : B → C) (f : A → B) : A → C := by\n  done\n"
  ),
  Exercise(
    id: "functionworld-l05-constantfunctions",
    title: "L05: Constant Functions",
    world: "Function World",
    initialSource: "example {A B : Type} (a : A) : B → A := by\n  done\n"
  ),
  Exercise(
    id: "functionworld-l06-multivariablefunctions",
    title: "L06: Multivariable Functions",
    world: "Function World",
    initialSource: "example {A B C : Type} (a : A) (f : A → B → C) : B → C := by\n  done\n"
  ),
  Exercise(
    id: "functionworld-l07-swappinginputs",
    title: "L07: Swapping Inputs",
    world: "Function World",
    initialSource: "example {A B C : Type} : (A → B → C) → (B → A → C) := by\n  done\n"
  ),
  Exercise(
    id: "functionworld-l08-compositionrevisited",
    title: "L08: Composition Revisited",
    world: "Function World",
    initialSource: "example {A B C : Type} : (B → C) → (A → B) → (A → C) := by\n  done\n"
  ),
  Exercise(
    id: "functionworld-l09-evaluation",
    title: "L09: Evaluation",
    world: "Function World",
    initialSource: "example {A B : Type} : A → (A → B) → B := by\n  done\n"
  ),
  Exercise(
    id: "functionworld-l10-bosslevel",
    title: "L10: Boss Level",
    world: "Function World",
    initialSource: "example {F V : Type} : ((((V → F) → F) → F) → F) → ((V → F) → F) := by\n  done\n"
  ),
  Exercise(
    id: "implicationworld-l01-byassumption",
    title: "L01: By Assumption",
    world: "Implication World",
    initialSource: "example {P : Prop} (p : P) : P := by\n  done\n"
  ),
  Exercise(
    id: "implicationworld-l02-modusponens",
    title: "L02: Modus Ponens",
    world: "Implication World",
    initialSource: "example {P Q : Prop} (p : P) (h : P → Q) : Q := by\n  done\n"
  ),
  Exercise(
    id: "implicationworld-l03-applyingimplication",
    title: "L03: Applying Implication",
    world: "Implication World",
    initialSource: "example {P Q : Prop} (p : P) (h : P → Q) : Q := by\n  done\n"
  ),
  Exercise(
    id: "implicationworld-l04-composingimplication",
    title: "L04: Composing Implication",
    world: "Implication World",
    initialSource: "example {P Q R : Prop} (p : P) (h1 : P → Q) (h2 : Q → R) : R := by\n  done\n"
  ),
  Exercise(
    id: "implicationworld-l05-provingimplication",
    title: "L05: Proving Implication",
    world: "Implication World",
    initialSource: "example {P : Prop} : P → P := by\n  done\n"
  ),
  Exercise(
    id: "implicationworld-l06-provingimpliedassumption",
    title: "L06: Proving Implied Assumption",
    world: "Implication World",
    initialSource: "example {P Q : Prop} (p : P) : Q → P := by\n  done\n"
  ),
  Exercise(
    id: "implicationworld-l07-provingassumedimplication",
    title: "L07: Proving Assumed Implication",
    world: "Implication World",
    initialSource: "example {P Q : Prop} (h : P → Q) : P → Q := by\n  done\n"
  ),
  Exercise(
    id: "implicationworld-l08-transitivity",
    title: "L08: Transitivity",
    world: "Implication World",
    initialSource: "example {P Q R : Prop} : (P → Q) → (Q → R) → (P → R) := by\n  done\n"
  ),
  Exercise(
    id: "implicationworld-l09-modusponensagain",
    title: "L09: Modus Ponens Again",
    world: "Implication World",
    initialSource: "example {P Q : Prop} : P → (P → Q) → Q := by\n  done\n"
  ),
  Exercise(
    id: "implicationworld-l10-bosslevel",
    title: "L10: Boss Level",
    world: "Implication World",
    initialSource: "example {P Q R S T U V W X Y Z : Prop} :\n    (S → X) → (T → W) → (R → Y) → (W → Q) → (U → S) → (Y → T) →\n    (X → V) → (Q → U) → (V → Z) → (P → R) → P → Z := by\n  done\n"
  ),
  Exercise(
    id: "productworld-l01-pairing",
    title: "L01: Pairing",
    world: "Product World",
    initialSource: "example {A B : Type} (a : A) (b : B) : A × B := by\n  done\n"
  ),
  Exercise(
    id: "productworld-l02-firstprojection",
    title: "L02: First Projection",
    world: "Product World",
    initialSource: "example {A B : Type} : A × B → A := by\n  done\n"
  ),
  Exercise(
    id: "productworld-l03-secondprojection",
    title: "L03: Second Projection",
    world: "Product World",
    initialSource: "example {A B : Type} : A × B → B := by\n  done\n"
  ),
  Exercise(
    id: "productworld-l04-symmetry",
    title: "L04: Symmetry",
    world: "Product World",
    initialSource: "example {A B : Type} : A × B → B × A := by\n  done\n"
  ),
  Exercise(
    id: "productworld-l05-associativity",
    title: "L05: Associativity",
    world: "Product World",
    initialSource: "example {A B C : Type} :\n    ((A × B) × C → A × (B × C)) × (A × (B × C) → (A × B) × C) := by\n  done\n"
  ),
  Exercise(
    id: "productworld-l06-currying",
    title: "L06: Currying",
    world: "Product World",
    initialSource: "example {A B C : Type} : (A × B → C) → (A → B → C) := by\n  done\n"
  ),
  Exercise(
    id: "productworld-l07-uncurrying",
    title: "L07: Uncurrying",
    world: "Product World",
    initialSource: "example {A B C : Type} : (A → B → C) → (A × B → C) := by\n  done\n"
  ),
  Exercise(
    id: "productworld-l08-componentfunctions",
    title: "L08: Component Functions",
    world: "Product World",
    initialSource: "example {X A B : Type} : (X → A × B) → (X → A) × (X → B) := by\n  done\n"
  ),
  Exercise(
    id: "productworld-l09-universalproperty",
    title: "L09: Universal Property",
    world: "Product World",
    initialSource: "example {X A B : Type} : (X → A) × (X → B) → (X → A × B) := by\n  done\n"
  ),
  Exercise(
    id: "productworld-l10-bosslevel",
    title: "L10: Boss Level",
    world: "Product World",
    initialSource: "example {A B C D E M N X Y Z : Type} :\n    (B × D → M) → (E → Y × N) → (A → M → X) → (C → N → Z) →\n    (A × B × C × D × E → X × Y × Z) := by\n  done\n"
  ),
  Exercise(
    id: "conjunctionworld-l01-introducingand",
    title: "L01: Introducing And",
    world: "Conjunction World",
    initialSource: "example {P Q : Prop} (p : P) (q : Q) : P ∧ Q := by\n  done\n"
  ),
  Exercise(
    id: "conjunctionworld-l02-usingand",
    title: "L02: Using And",
    world: "Conjunction World",
    initialSource: "example {P Q : Prop} (h : P ∧ Q) : P ∧ Q := by\n  done\n"
  ),
  Exercise(
    id: "conjunctionworld-l03-symmetry",
    title: "L03: Symmetry",
    world: "Conjunction World",
    initialSource: "example {P Q : Prop} : P ∧ Q → Q ∧ P := by\n  done\n"
  ),
  Exercise(
    id: "conjunctionworld-l04-logicalequivalence",
    title: "L04: Logical Equivalence",
    world: "Conjunction World",
    initialSource: "example {P Q : Prop} : P ∧ Q ↔ Q ∧ P := by\n  done\n"
  ),
  Exercise(
    id: "conjunctionworld-l05-associativity",
    title: "L05: Associativity",
    world: "Conjunction World",
    initialSource: "example {P Q R : Prop} : (P ∧ Q) ∧ R ↔ P ∧ (Q ∧ R) := by\n  done\n"
  ),
  Exercise(
    id: "conjunctionworld-l06-compoundimplication",
    title: "L06: Compound Implication",
    world: "Conjunction World",
    initialSource: "example {P Q R : Prop} (h : P ∧ Q → R) : P → Q → R := by\n  done\n"
  ),
  Exercise(
    id: "conjunctionworld-l07-morecompoundimplication",
    title: "L07: More Compound Implication",
    world: "Conjunction World",
    initialSource: "example {P Q R : Prop} (h : P → Q → R) : P ∧ Q → R := by\n  done\n"
  ),
  Exercise(
    id: "conjunctionworld-l08-curryingimplication",
    title: "L08: Currying Implication",
    world: "Conjunction World",
    initialSource: "example {P Q R : Prop} : (P ∧ Q → R) ↔ (P → Q → R) := by\n  done\n"
  ),
  Exercise(
    id: "conjunctionworld-l09-universalproperty",
    title: "L09: Universal Property",
    world: "Conjunction World",
    initialSource: "example {P Q R : Prop} : (P → Q) ∧ (P → R) ↔ P → Q ∧ R := by\n  done\n"
  ),
  Exercise(
    id: "conjunctionworld-l10-bosslevel",
    title: "L10: Boss Level",
    world: "Conjunction World",
    initialSource: "example {P Q R S T U V W X Y Z : Prop} :\n    P → (R → S ∧ T) → (U → P → R) → ((U → Y) → Z) →\n    (W ∧ T ∧ V → X ∧ Y) → (S → V ∧ W) → Z := by\n  done\n"
  ),
  Exercise(
    id: "coproductworld-l01-leftinclusion",
    title: "L01: Left Inclusion",
    world: "Coproduct World",
    initialSource: "example {A B : Type} (a : A) : A ⊕ B := by\n  done\n"
  ),
  Exercise(
    id: "coproductworld-l02-rightinclusion",
    title: "L02: Right Inclusion",
    world: "Coproduct World",
    initialSource: "example {A B : Type} (b : B) : A ⊕ B := by\n  done\n"
  ),
  Exercise(
    id: "coproductworld-l03-componentfunctions",
    title: "L03: Component Functions",
    world: "Coproduct World",
    initialSource: "example {A B C : Type} : (A ⊕ B → C) → (A → C) × (B → C) := by\n  done\n"
  ),
  Exercise(
    id: "coproductworld-l04-universalproperty",
    title: "L04: Universal Property",
    world: "Coproduct World",
    initialSource: "example {A B C : Type} (g : A → C) (h : B → C) : A ⊕ B → C := by\n  done\n"
  ),
  Exercise(
    id: "coproductworld-l05-symmetry",
    title: "L05: Symmetry",
    world: "Coproduct World",
    initialSource: "example {A B : Type} : A ⊕ B → B ⊕ A := by\n  done\n"
  ),
  Exercise(
    id: "coproductworld-l06-associativity",
    title: "L06: Associativity",
    world: "Coproduct World",
    initialSource: "example {A B C : Type} :\n    ((A ⊕ B) ⊕ C → A ⊕ (B ⊕ C)) × (A ⊕ (B ⊕ C) → (A ⊕ B) ⊕ C) := by\n  done\n"
  ),
  Exercise(
    id: "coproductworld-l07-distributivity",
    title: "L07: Distributivity",
    world: "Coproduct World",
    initialSource: "example {A B C : Type} :\n    (A × (B ⊕ C) → (A × B) ⊕ (A × C)) × ((A × B) ⊕ (A × C) → A × (B ⊕ C)) := by\n  done\n"
  ),
  Exercise(
    id: "coproductworld-l08-bosslevel",
    title: "L08: Boss Level",
    world: "Coproduct World",
    initialSource: "example {A B C D : Type} :\n    ((A ⊕ B → C × D) → (A → C) × (B → C) × (A → D) × (B → D)) ×\n      ((A → C) × (B → C) × (A → D) × (B → D) → (A ⊕ B → C × D)) := by\n  done\n"
  ),
  Exercise(
    id: "disjunctionworld-l01-introducingor",
    title: "L01: Introducing Or",
    world: "Disjunction World",
    initialSource: "example {P Q : Prop} (p : P) (q : Q) : P ∨ Q := by\n  done\n"
  ),
  Exercise(
    id: "disjunctionworld-l02-andimpliesor",
    title: "L02: And Implies Or",
    world: "Disjunction World",
    initialSource: "example {P Q : Prop} : P ∧ Q → P ∨ Q := by\n  done\n"
  ),
  Exercise(
    id: "disjunctionworld-l03-usingor",
    title: "L03: Using Or",
    world: "Disjunction World",
    initialSource: "example {P Q : Prop} : P ∨ Q → Q ∨ P := by\n  done\n"
  ),
  Exercise(
    id: "disjunctionworld-l04-symmetry",
    title: "L04: Symmetry",
    world: "Disjunction World",
    initialSource: "example {P Q : Prop} : P ∨ Q ↔ Q ∨ P := by\n  done\n"
  ),
  Exercise(
    id: "disjunctionworld-l05-universalproperty",
    title: "L05: Universal Property",
    world: "Disjunction World",
    initialSource: "example {P Q R : Prop} : (P ∨ Q → R) ↔ (P → R) ∧ (Q → R) := by\n  done\n"
  ),
  Exercise(
    id: "disjunctionworld-l06-associativity",
    title: "L06: Associativity",
    world: "Disjunction World",
    initialSource: "example {P Q R : Prop} : (P ∨ Q) ∨ R ↔ P ∨ Q ∨ R := by\n  done\n"
  ),
  Exercise(
    id: "disjunctionworld-l07-distributivity",
    title: "L07: Distributivity",
    world: "Disjunction World",
    initialSource: "example {P Q R : Prop} : P ∧ (Q ∨ R) ↔ (P ∧ Q) ∨ (P ∧ R) := by\n  done\n"
  ),
  Exercise(
    id: "disjunctionworld-l08-moredistributivity",
    title: "L08: More Distributivity",
    world: "Disjunction World",
    initialSource: "example {P Q R S : Prop} :\n    (P ∨ Q) ∧ (R ∨ S) ↔ (P ∧ R) ∨ (P ∧ S) ∨ (Q ∧ R) ∨ (Q ∧ S) := by\n  done\n"
  ),
  Exercise(
    id: "disjunctionworld-l09-bosslevel",
    title: "L09: Boss Level",
    world: "Disjunction World",
    initialSource: "example {P Q R S T U V W X Y Z : Prop} :\n    (T ∨ U → V ∧ Y) → (Q → P → T) → (Y → Q → W) →\n    ((V ∧ W) ∨ (X ∧ Y) → Z) → (R → S → U) ∧ (V → R → X) →\n    P ∧ (Q ∨ R) ∧ S → Z := by\n  done\n"
  ),
]

func worldIntroId(for world: String) -> String {
  switch world {
  case "Type World": return "typeworld-intro"
  case "Function World": return "functionworld-intro"
  case "Implication World": return "implicationworld-intro"
  case "Product World": return "productworld-intro"
  case "Conjunction World": return "conjunctionworld-intro"
  case "Coproduct World": return "coproductworld-intro"
  case "Disjunction World": return "disjunctionworld-intro"
  default: return "\(world.lowercased().replacingOccurrences(of: " ", with: ""))-intro"
  }
}

let worldGroups: [WorldGroup] = {
  var groups: [WorldGroup] = []
  for ex in exercises {
    if let last = groups.last, last.world == ex.world {
      var merged = groups.removeLast().exercises
      merged.append(ex)
      groups.append(WorldGroup(world: ex.world, exercises: merged))
    } else {
      groups.append(WorldGroup(world: ex.world, exercises: [ex]))
    }
  }
  return groups.map { group in
    let intro = Exercise(
      id: worldIntroId(for: group.world),
      title: "L00: \(group.world)",
      world: group.world,
      initialSource: "",
      isWorldIntro: true
    )
    return WorldGroup(world: group.world, exercises: [intro] + group.exercises)
  }
}()

struct RootView: View {
  @State private var path = NavigationPath()
  @State private var selectedGame = 0
  @AppStorage(NNGProgress.key) private var nngCompletedRaw = ""

  private var nngAvailable: Bool { !NNGGameStore.shared.worldGroups.isEmpty }

  var body: some View {
    NavigationStack(path: $path) {
      List {
        if nngAvailable {
          Section {
            Picker("Game", selection: $selectedGame) {
              Text("Proofs").tag(0)
              Text("Numbers").tag(1)
            }
            .pickerStyle(.segmented)
          }
        }
        if selectedGame == 0 || !nngAvailable {
          ForEach(worldGroups) { group in
            Section(group.world) {
              ForEach(group.exercises) { ex in
                NavigationLink(value: ex) { row(ex) }
              }
            }
          }
        } else {
          ForEach(NNGGameStore.shared.worldGroups) { group in
            Section {
              ForEach(group.exercises) { ex in
                NavigationLink(value: ex) { row(ex) }
              }
            } header: {
              nngWorldHeader(group.world)
            }
          }
        }
      }
      .navigationTitle("iOS Lean")
      .navigationDestination(for: Exercise.self) { ex in
        if ex.nng != nil {
          NNGIntroView(exercise: ex)
        } else {
          IntroView(exercise: ex, mode: .lesson)
        }
      }
      .navigationDestination(for: ProofPath.self) { p in
        ExerciseView(exercise: p.exercise, path: $path)
      }
    }
  }

  private func row(_ ex: Exercise) -> some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 4) {
        Text(ex.title)
          .font(.system(size: 15, weight: .semibold, design: .rounded))
        Text(firstLine(visibleSource(ex)))
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.tail)
      }
      if ex.nng != nil && nngCompleted.contains(ex.id) {
        Spacer()
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 15))
          .foregroundStyle(.green)
      }
    }
    .padding(.vertical, 4)
  }

  private func nngWorldHeader(_ world: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(world)
      if let intro = NNGGameStore.shared.worldIntros[world], !intro.isEmpty {
        Text(nngMarkdown(intro.trimmingCharacters(in: .whitespacesAndNewlines)))
          .font(.system(size: 12))
          .textCase(nil)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var nngCompleted: Set<String> {
    Set(nngCompletedRaw.split(separator: ",").map(String.init))
  }

  private func visibleSource(_ ex: Exercise) -> String {
    ex.nng != nil ? nngVisibleSource(ex) : ex.initialSource
  }

  private func firstLine(_ s: String) -> String {
    s.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
  }
}
