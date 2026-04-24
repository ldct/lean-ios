import SwiftUI

@main
struct LeanIOSElabExampleApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}

private struct ContentView: View {
  @State private var source = """
    import Lean

    #check Nat.succ

    example : 1 = 1 := rfl

    def foo (n : Nat) : Nat := n + 1

    #eval foo 1
    """

  @State private var output = "No messages yet."
  @State private var isRunning = false

  var body: some View {
    ZStack {
      Color(.systemGroupedBackground).ignoresSafeArea()

      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 10) {
          Text("iOS Lean")
            .font(.system(size: 34, weight: .black, design: .rounded))
            .foregroundStyle(.primary)
        }

        HStack(alignment: .center, spacing: 12) {
          Button(action: runCheck) {
            HStack(spacing: 8) {
              Text("Run")
                .font(.system(size: 15, weight: .bold, design: .rounded))
            }
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

        VStack(alignment: .leading, spacing: 10) {
          panelHeader(title: "Source")

          TextEditor(text: $source)
            .font(.system(size: 15, weight: .regular, design: .monospaced))
            .disableAutocorrection(true)
            .textInputAutocapitalization(.never)
            .scrollContentBackground(.hidden)
            .padding(14)
            .frame(minHeight: 220, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }

        VStack(alignment: .leading, spacing: 10) {
          panelHeader(title: "Output")

          ScrollView {
            Text(output)
              .font(.system(size: 14, weight: .regular, design: .monospaced))
              .foregroundStyle(Color.white)
              .frame(maxWidth: .infinity, alignment: .leading)
              .textSelection(.enabled)
              .padding(14)
          }
          .frame(minHeight: 220, maxHeight: .infinity)
          .background(Color.black)
        }
      }
      .padding(20)
    }
  }

  private func panelHeader(title: String) -> some View {
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
      output = "Bridge call failed."
      return
    }
    guard
      let (decodedOutput, _) = String.decodeCString(
        UnsafeRawPointer(raw).assumingMemoryBound(to: UTF8.CodeUnit.self),
        as: UTF8.self,
      )
    else {
      output = "Output string decoding failed"
      return
    }
    output = decodedOutput
  }
}
