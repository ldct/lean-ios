import SwiftUI

/// Render NNG prose (level intros, hints, docs): inline markdown per
/// paragraph, with fenced/indented code blocks shown monospaced.
func nngMarkdown(_ s: String) -> AttributedString {
  (try? AttributedString(
    markdown: s,
    options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
    ?? AttributedString(s)
}

private enum NNGPalette {
  static let accent = Color(red: 0.96, green: 0.45, blue: 0.16)
  static let card = Color(.secondarySystemGroupedBackground)
  static let cardStroke = Color(.systemGray5)
}

private func proseText(_ s: String) -> some View {
  Text(nngMarkdown(s.trimmingCharacters(in: .whitespacesAndNewlines)))
    .font(.system(size: 15))
    .lineSpacing(3)
    .frame(maxWidth: .infinity, alignment: .leading)
}

private func codeCard(_ code: String) -> some View {
  Text(highlight(code))
    .font(.system(size: 15, design: .monospaced))
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(NNGPalette.card)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(NNGPalette.cardStroke, lineWidth: 1)
    )
}

/// Visible (player-facing) part of an exercise source: the hidden prelude
/// and the trailing `done` are stripped.
func nngVisibleSource(_ exercise: Exercise) -> String {
  var s = exercise.initialSource
  if !exercise.hiddenPrelude.isEmpty, s.hasPrefix(exercise.hiddenPrelude) {
    s.removeFirst(exercise.hiddenPrelude.count)
  }
  if let range = s.range(of: "  done\n", options: .backwards) {
    s.replaceSubrange(range, with: "")
  }
  if s.hasSuffix("\n") { s.removeLast() }
  return s
}

// MARK: - Level introduction (navigation destination before the proof)

struct NNGIntroView: View {
  let exercise: Exercise

  private var nng: NNGLevelInfo { exercise.nng! }

  var body: some View {
    ZStack {
      Color(.systemGroupedBackground).ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text(nng.worldTitle.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(.secondary)
          Text(exercise.title)
            .font(.system(size: 24, weight: .bold, design: .rounded))
          if !nng.introduction.isEmpty {
            proseText(nng.introduction)
          }
          if !nng.statementDoc.isEmpty {
            proseText(nng.statementDoc)
              .padding(12)
              .background(NNGPalette.card)
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
          codeCard(nngVisibleSource(exercise))
          NavigationLink(value: ProofPath(exercise: exercise)) {
            Text("Start the proof")
              .font(.system(size: 16, weight: .bold, design: .rounded))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background(NNGPalette.accent)
              .clipShape(Capsule())
          }
          .padding(.top, 8)
        }
        .padding(20)
      }
    }
  }
}

// MARK: - Hints sheet (from the proof screen)

struct NNGInfoSheet: View {
  let exercise: Exercise
  @State private var showHidden = false

  private var nng: NNGLevelInfo { exercise.nng! }
  private var visibleHints: [NNGHintInfo] { nng.hints.filter { !$0.hidden } }
  private var hiddenHints: [NNGHintInfo] { nng.hints.filter { $0.hidden } }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("HINTS · \(exercise.title)")
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .tracking(0.6)
          .foregroundStyle(.secondary)
        if !nng.introduction.isEmpty {
          proseText(nng.introduction)
        }
        if nng.hints.isEmpty {
          Text("No hints for this level.")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
        }
        ForEach(Array(visibleHints.enumerated()), id: \.offset) { _, hint in
          hintCard(hint)
        }
        if !hiddenHints.isEmpty {
          if showHidden {
            ForEach(Array(hiddenHints.enumerated()), id: \.offset) { _, hint in
              hintCard(hint)
            }
          } else {
            Button(action: { showHidden = true }) {
              Text("Show \(hiddenHints.count) more hint\(hiddenHints.count == 1 ? "" : "s")")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(NNGPalette.accent)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(20)
    }
    .presentationDetents([.medium, .large])
  }

  private func hintCard(_ hint: NNGHintInfo) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "lightbulb")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(NNGPalette.accent)
        .padding(.top, 2)
      proseText(hint.text)
    }
    .padding(12)
    .background(NNGPalette.card)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(NNGPalette.cardStroke, lineWidth: 1)
    )
  }
}

// MARK: - Inventory sheet (unlocked theorems & tactics with docs)

struct NNGInventoryView: View {
  let nng: NNGLevelInfo
  @State private var segment = 0

  var body: some View {
    VStack(spacing: 0) {
      Picker("Inventory", selection: $segment) {
        Text("Theorems").tag(0)
        Text("Tactics").tag(1)
      }
      .pickerStyle(.segmented)
      .padding(16)
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          let names = segment == 0 ? nng.theorems : nng.tactics
          if names.isEmpty {
            Text("Nothing unlocked yet.")
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
          }
          ForEach(names, id: \.self) { name in
            entryCard(name: name, doc: doc(for: name))
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
      }
    }
  }

  private func doc(for name: String) -> NNGDocEntry? {
    segment == 0
      ? NNGGameStore.shared.theoremDocs[name]
      : NNGGameStore.shared.tacticDocs[name]
  }

  private func entryCard(name: String, doc: NNGDocEntry?) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(doc?.displayName ?? name)
        .font(.system(size: 15, weight: .bold, design: .monospaced))
      if let content = doc?.content, !content.isEmpty {
        proseText(content)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(NNGPalette.card)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(NNGPalette.cardStroke, lineWidth: 1)
    )
  }
}
