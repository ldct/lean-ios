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

struct ExerciseView: View {
  let exercise: Exercise
  @State private var source: String = ""
  @State private var input: String = ""
  @State private var state: CheckState = .idle
  @State private var isRunning = false

  private static let sourceLineHeight: CGFloat = 22

  var body: some View {
    ZStack {
      Color(.systemGroupedBackground).ignoresSafeArea()
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 8) {
          panelHeader("Source")
          ScrollView {
            Text(source)
              .font(.system(size: 14, design: .monospaced))
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .textSelection(.enabled)
          }
          .frame(height: 5 * Self.sourceLineHeight + 24)
          .background(Color(.systemBackground))
        }

        VStack(alignment: .leading, spacing: 8) {
          panelHeader("State")
          ScrollView {
            VStack(alignment: .leading, spacing: 12) { stateView }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(14)
          }
          .frame(maxHeight: .infinity)
          .background(Color(.systemBackground))
        }

        HStack(spacing: 8) {
          TextField("next tactic", text: $input)
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 15, design: .monospaced))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit(send)
            .disabled(isRunning)
          Button(action: send) {
            Text("Run")
              .font(.system(size: 15, weight: .bold, design: .rounded))
              .padding(.horizontal, 16)
              .padding(.vertical, 10)
          }
          .buttonStyle(.plain)
          .foregroundStyle(.white)
          .background(Color.orange)
          .clipShape(Capsule())
          .disabled(isRunning)
          .opacity(isRunning ? 0.7 : 1.0)
        }
      }
      .padding(20)
    }
    .navigationTitle(exercise.title)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      if source.isEmpty {
        source = exercise.initialSource
        runCheck()
      }
    }
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

  @ViewBuilder
  private var stateView: some View {
    switch state {
    case .idle:
      Text("Press Run.")
        .font(.system(size: 14, design: .monospaced))
        .foregroundStyle(.secondary)
    case .bridgeError(let msg):
      Text(msg)
        .font(.system(size: 14, design: .monospaced))
        .foregroundStyle(.red)
        .textSelection(.enabled)
    case .ok(let result):
      if result.complete {
        Text("Proof complete")
          .font(.system(size: 16, weight: .bold, design: .rounded))
          .foregroundStyle(.green)
      }
      if !result.goals.isEmpty {
        GoalsView(goals: result.goals)
      } else if !result.complete && result.diagnostics.isEmpty {
        Text("No `done` reached — end the proof with `done` to inspect the state.")
          .font(.system(size: 13, design: .monospaced))
          .foregroundStyle(.secondary)
      }
      if !result.diagnostics.isEmpty {
        DiagnosticsView(diagnostics: result.diagnostics)
      }
    }
  }

  private func panelHeader(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 16, weight: .bold, design: .rounded))
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
}

private struct GoalsView: View {
  let goals: [Goal]
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      ForEach(Array(goals.enumerated()), id: \.offset) { idx, goal in
        GoalView(goal: goal, index: idx, total: goals.count)
      }
    }
  }
}

private struct GoalView: View {
  let goal: Goal
  let index: Int
  let total: Int
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        if total > 1 {
          Text("Goal \(index + 1) of \(total)")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
        }
        if let tag = goal.caseTag {
          Text("case \(tag)")
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(.secondary)
        }
      }
      ForEach(Array(goal.hypotheses.enumerated()), id: \.offset) { _, hyp in
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(hyp.names.joined(separator: " "))
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
          Text(":")
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(.secondary)
          Text(hyp.type)
            .font(.system(size: 14, design: .monospaced))
            .textSelection(.enabled)
        }
      }
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text("⊢")
          .font(.system(size: 14, design: .monospaced))
          .foregroundStyle(.blue)
        Text(goal.target)
          .font(.system(size: 14, weight: .semibold, design: .monospaced))
          .textSelection(.enabled)
      }
    }
    .padding(.vertical, 4)
  }
}

private struct DiagnosticsView: View {
  let diagnostics: [Diagnostic]
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Diagnostics")
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .foregroundStyle(.secondary)
      ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, d in
        VStack(alignment: .leading, spacing: 2) {
          Text("\(d.severity) \(d.line):\(d.column)")
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(d.severity == "error" ? .red : .orange)
          Text(d.message)
            .font(.system(size: 13, design: .monospaced))
            .textSelection(.enabled)
        }
      }
    }
  }
}
