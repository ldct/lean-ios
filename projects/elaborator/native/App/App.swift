import SwiftUI

@main
struct LeanIOSElabExampleApp: App {
  var body: some Scene {
    WindowGroup {
      RootView()
    }
  }
}

struct Exercise: Identifiable, Hashable {
  let id: String
  let title: String
  let initialSource: String
}

let exercises: [Exercise] = [
  Exercise(
    id: "identity",
    title: "Identity function",
    initialSource:
      "example {A : Type} : A → A := by\n" +
      "  done\n"
  ),
  Exercise(
    id: "apply",
    title: "Apply a function",
    initialSource:
      "example {A B : Type} (a : A) (f : A → B) : B := by\n" +
      "  done\n"
  ),
]

struct RootView: View {
  var body: some View {
    NavigationStack {
      List(exercises) { ex in
        NavigationLink(value: ex) {
          VStack(alignment: .leading, spacing: 6) {
            Text(ex.title)
              .font(.system(size: 17, weight: .bold, design: .rounded))
            Text(firstLine(ex.initialSource))
              .font(.system(size: 13, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.tail)
          }
          .padding(.vertical, 6)
        }
      }
      .navigationTitle("iOS Lean")
      .navigationDestination(for: Exercise.self) { ex in
        ExerciseView(exercise: ex)
      }
    }
  }

  private func firstLine(_ s: String) -> String {
    s.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
  }
}
