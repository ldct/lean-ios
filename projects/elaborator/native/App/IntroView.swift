import SwiftUI

enum IntroSegment {
  case word(String)
  case emphasis(String)
  case identPill(String)
  case tacticPill(String)
}

struct IntroParagraph {
  let segments: [IntroSegment]
}

enum IntroMode {
  case lesson
  case review
}

struct IntroView: View {
  let exercise: Exercise
  var mode: IntroMode = .lesson
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack(alignment: .bottom) {
      Color(.systemGroupedBackground).ignoresSafeArea()
      VStack(spacing: 0) {
        topBar
          .padding(.horizontal, 16)
          .padding(.bottom, 8)
        ScrollView {
          VStack(alignment: .leading, spacing: 14) {
            eyebrow
            Text(displayName)
              .font(.system(size: 32, weight: .heavy, design: .rounded))
              .padding(.top, 4)
              .padding(.bottom, 8)
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, p in
              paragraphCard(p)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16)
          .padding(.bottom, mode == .lesson ? 96 : 24)
        }
      }
      if mode == .lesson {
        startButton
          .padding(.horizontal, 16)
          .padding(.bottom, 8)
      }
    }
    .toolbar(.hidden, for: .navigationBar)
  }

  private var topBar: some View {
    HStack {
      Button(action: { dismiss() }) {
        Image(systemName: "xmark")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(.primary)
          .frame(width: 38, height: 38)
          .background(Color(.systemBackground))
          .clipShape(Circle())
          .overlay(Circle().stroke(IntroPalette.cardStroke, lineWidth: 1))
      }
      Spacer()
      HStack(spacing: 5) {
        Circle().fill(IntroPalette.accent).frame(width: 6, height: 6)
        Text("\(lessonNumber) / \(totalLessons)")
          .font(.system(size: 13, weight: .semibold, design: .rounded))
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(Color(.systemBackground))
      .clipShape(Capsule())
      .overlay(Capsule().stroke(IntroPalette.cardStroke, lineWidth: 1))
    }
  }

  private var eyebrow: some View {
    HStack(spacing: 10) {
      Text(lessonCode)
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .foregroundStyle(IntroPalette.accent)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(IntroPalette.accentSoft.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
      Text("CHAPTER \(chapterNumber) · \(exercise.world.uppercased())")
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .tracking(0.6)
        .foregroundStyle(.secondary)
      Spacer()
    }
  }

  private func paragraphCard(_ p: IntroParagraph) -> some View {
    FlowLayout(spacing: 4, lineSpacing: 6) {
      ForEach(Array(flowItems(for: p).enumerated()), id: \.offset) { _, item in
        flowItemView(item)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(IntroPalette.cardCream)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  @ViewBuilder
  private func flowItemView(_ item: FlowItem) -> some View {
    switch item {
    case .word(let s):
      Text(s)
        .font(.system(size: 15))
        .foregroundStyle(.primary)
    case .emphasis(let s):
      Text(s)
        .font(.system(size: 15).italic())
        .foregroundStyle(.primary)
    case .identPill(let s):
      Text(s)
        .font(.system(size: 14, design: .monospaced))
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Color(.systemBackground))
        .overlay(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(IntroPalette.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    case .tacticPill(let s):
      Text(s)
        .font(.system(size: 14, design: .monospaced))
        .foregroundStyle(IntroPalette.tactic)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(IntroPalette.tactic.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
  }

  private var startButton: some View {
    NavigationLink(value: ProofPath(exercise: exercise)) {
      HStack(spacing: 6) {
        Text("Start the proof")
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .bold))
      }
      .font(.system(size: 17, weight: .bold, design: .rounded))
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 16)
      .background(IntroPalette.accent)
      .clipShape(Capsule())
      .shadow(color: IntroPalette.accent.opacity(0.25), radius: 12, y: 4)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Derived strings

  private var lessonCode: String {
    if let colon = exercise.title.firstIndex(of: ":") {
      return String(exercise.title[..<colon]).trimmingCharacters(in: .whitespaces)
    }
    return exercise.title
  }

  private var displayName: String {
    if let colon = exercise.title.firstIndex(of: ":") {
      return String(exercise.title[exercise.title.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
    }
    return exercise.title
  }

  private var chapterNumber: Int {
    (worldGroups.firstIndex { $0.world == exercise.world } ?? 0) + 1
  }

  private var lessonNumber: Int {
    let group = worldGroups.first { $0.world == exercise.world }
    return (group?.exercises.firstIndex(of: exercise) ?? 0) + 1
  }

  private var totalLessons: Int {
    worldGroups.first { $0.world == exercise.world }?.exercises.count ?? 0
  }

  private var paragraphs: [IntroParagraph] {
    if let authored = introContent[exercise.id] { return authored }
    return [
      IntroParagraph(segments: [
        .word("Goal:"),
        .word("prove"),
        .word("the"),
        .word("statement"),
        .word("below."),
      ]),
      IntroParagraph(segments: [
        .word("Tap"),
        .word("a"),
        .word("tactic,"),
        .word("then"),
        .word("a"),
        .word("constant"),
        .word("or"),
        .word("a"),
        .word("fresh"),
        .word("name,"),
        .word("and"),
        .word("press"),
        .tacticPill("Run"),
        .word("."),
      ]),
    ]
  }

  // MARK: - Flow flattening

  private enum FlowItem {
    case word(String)
    case emphasis(String)
    case identPill(String)
    case tacticPill(String)
  }

  private func flowItems(for p: IntroParagraph) -> [FlowItem] {
    var out: [FlowItem] = []
    for seg in p.segments {
      switch seg {
      case .word(let s):
        for w in tokenize(s) { out.append(.word(w)) }
      case .emphasis(let s):
        for w in tokenize(s) { out.append(.emphasis(w)) }
      case .identPill(let s):
        out.append(.identPill(s))
      case .tacticPill(let s):
        out.append(.tacticPill(s))
      }
    }
    return out
  }

  private func tokenize(_ s: String) -> [String] {
    s.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
  }
}

// MARK: - Flow layout

struct FlowLayout: Layout {
  var spacing: CGFloat = 4
  var lineSpacing: CGFloat = 6

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    var x: CGFloat = 0
    var y: CGFloat = 0
    var lineHeight: CGFloat = 0
    var maxX: CGFloat = 0
    for sub in subviews {
      let size = sub.sizeThatFits(.unspecified)
      if x + size.width > maxWidth && x > 0 {
        maxX = max(maxX, x - spacing)
        x = 0
        y += lineHeight + lineSpacing
        lineHeight = 0
      }
      x += size.width + spacing
      lineHeight = max(lineHeight, size.height)
    }
    maxX = max(maxX, x - spacing)
    return CGSize(width: max(0, maxX), height: y + lineHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let maxWidth = bounds.width
    var x: CGFloat = 0
    var y: CGFloat = 0
    var lineHeight: CGFloat = 0
    for sub in subviews {
      let size = sub.sizeThatFits(.unspecified)
      if x + size.width > maxWidth && x > 0 {
        x = 0
        y += lineHeight + lineSpacing
        lineHeight = 0
      }
      sub.place(
        at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
        proposal: ProposedViewSize(width: size.width, height: size.height)
      )
      x += size.width + spacing
      lineHeight = max(lineHeight, size.height)
    }
  }
}

// MARK: - Palette (intro-local)

private enum IntroPalette {
  static let accent = Color(red: 0.96, green: 0.45, blue: 0.16)
  static let accentSoft = Color(red: 0.99, green: 0.83, blue: 0.69)
  static let cardStroke = Color(.systemGray5)
  static let cardCream = Color(red: 0.99, green: 0.96, blue: 0.93)
  static let tactic = Color(red: 0.42, green: 0.32, blue: 0.78)
}

// MARK: - Tactic reference (placeholder)

struct TacticReferenceView: View {
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    ZStack(alignment: .topTrailing) {
      Color(.systemGroupedBackground).ignoresSafeArea()
      VStack(spacing: 12) {
        Spacer()
        Image(systemName: "rectangle.split.2x1")
          .font(.system(size: 36))
          .foregroundStyle(.secondary)
        Text("Tactic reference WIP")
          .font(.system(size: 18, weight: .semibold, design: .rounded))
          .foregroundStyle(.secondary)
        Spacer()
      }
      .frame(maxWidth: .infinity)
      Button(action: { dismiss() }) {
        Image(systemName: "xmark")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(.primary)
          .frame(width: 38, height: 38)
          .background(Color(.systemBackground))
          .clipShape(Circle())
          .overlay(Circle().stroke(Color(.systemGray5), lineWidth: 1))
      }
      .padding(.top, 12)
      .padding(.trailing, 16)
    }
  }
}

// MARK: - Authored intro content

let introContent: [String: [IntroParagraph]] = [
  "typeworld-l01-elements": [
    IntroParagraph(segments: [
      .word("An interactive theorem prover — in this case Lean — helps the user — this means you — keep track of the state of a proof or a mathematical construction."),
    ]),
    IntroParagraph(segments: [
      .word("In the"),
      .identPill("Active Goal"),
      .word("window, Lean keeps track of the"),
      .identPill("objects"),
      .word("and"),
      .identPill("assumptions"),
      .word("— which together define the hypotheses of a mathematical statement — as well as the"),
      .identPill("goal"),
      .word("— meaning the thing we are trying to prove."),
    ]),
    IntroParagraph(segments: [
      .word("The objects and assumptions together define the mathematical"),
      .emphasis("context"),
      .word("for a given theorem or construction."),
    ]),
    IntroParagraph(segments: [
      .word("Here our context is given by a single type"),
      .identPill("A"),
      .word("with a hypothesized element"),
      .identPill("a : A"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("On the right-hand side we see the name of a type, which is the"),
      .emphasis("goal"),
      .word("for this level. Here that type is"),
      .identPill("A"),
      .word(", which means that our goal is to define an element of type"),
      .identPill("A"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("We have such an element by assumption, and you can type"),
      .tacticPill("assumption"),
      .word("to tell Lean this. Then type"),
      .identPill("enter"),
      .word("or click the button"),
      .identPill("Execute"),
      .word("to ask Lean to check your work."),
    ]),
    IntroParagraph(segments: [
      .word("Here"),
      .tacticPill("assumption"),
      .word("is an example of a"),
      .emphasis("tactic"),
      .word(", which is built into Lean. You can find this in the tactic library on the upper right."),
    ]),
  ],

  "typeworld-l02-proofs": [
    IntroParagraph(segments: [
      .word("In this level, we consider a proposition"),
      .identPill("P"),
      .word("in place of a type"),
      .identPill("A"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("When a proposition"),
      .identPill("P"),
      .word("has an element"),
      .identPill("p : P"),
      .word("we think of"),
      .identPill("p"),
      .word("as a"),
      .emphasis("proof"),
      .word("that"),
      .identPill("P"),
      .word("is true."),
    ]),
    IntroParagraph(segments: [
      .word("It is useful to have an explicit name"),
      .identPill("p"),
      .word("for the proof that"),
      .identPill("P"),
      .word("is true. When we reference the truth of"),
      .identPill("P"),
      .word("to prove other propositions, we will do so by referring to"),
      .identPill("p"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Our goal is to prove the proposition"),
      .identPill("P"),
      .word(". We know"),
      .identPill("P"),
      .word("is true because we have assumed it, so the tactic"),
      .tacticPill("assumption"),
      .word("can close the goal."),
    ]),
  ],

  "typeworld-l03-exactelements": [
    IntroParagraph(segments: [
      .word("A more elaborate context may contain multiple types and multiple elements, or a mix of types, elements, propositions, and proofs."),
    ]),
    IntroParagraph(segments: [
      .word("Thus we may require a more precise way to tell Lean which datum from our context should be used."),
    ]),
    IntroParagraph(segments: [
      .word("Here the context includes two types"),
      .identPill("A"),
      .word("and"),
      .identPill("B"),
      .word("with three elements between them. Note the use of a space to indicate that"),
      .identPill("y : B"),
      .word("and"),
      .identPill("z : B"),
      .word("each define elements of type"),
      .identPill("B"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("The goal is to define an element of type"),
      .identPill("B"),
      .word(". The tactic"),
      .tacticPill("assumption"),
      .word("would solve this, but it does not convey to the reader which assumption was used."),
    ]),
    IntroParagraph(segments: [
      .word("It is better practice to use the tactic"),
      .tacticPill("exact"),
      .word(". If the goal has type"),
      .identPill("E"),
      .word("and there is an element"),
      .identPill("e : E"),
      .word("in the context, then"),
      .identPill("exact e"),
      .word("uses"),
      .identPill("e"),
      .word("to close the goal."),
    ]),
  ],

  "typeworld-l04-unittype": [
    IntroParagraph(segments: [
      .word("The previous levels involved type variables or proposition variables. But there are other specific types or propositions that exist in the empty context — in other words, types that are globally defined."),
    ]),
    IntroParagraph(segments: [
      .word("One example is the"),
      .emphasis("unit type"),
      .identPill("Unit"),
      .word("which has a canonical element"),
      .identPill("⟨⟩ : Unit"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Here the goal has type"),
      .identPill("Unit"),
      .word(". We cannot solve this with"),
      .tacticPill("assumption"),
      .word("because there are no assumptions! But"),
      .tacticPill("exact"),
      .word("together with the canonical element will close the goal."),
    ]),
    IntroParagraph(segments: [
      .word("Use"),
      .identPill("\\<"),
      .word("and"),
      .identPill("\\>"),
      .word("to type the angle brackets"),
      .identPill("⟨⟩"),
      .word("."),
    ]),
  ],

  "typeworld-l05-typeofpropositions": [
    IntroParagraph(segments: [
      .word("Lean has a built-in type of propositions denoted"),
      .identPill("Prop"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("In the empty context,"),
      .identPill("Prop"),
      .word("contains propositions like"),
      .identPill("True"),
      .word(", the true proposition, with canonical proof"),
      .identPill("⟨⟩ : True"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("In this level, the context contains two propositions"),
      .identPill("P"),
      .word("and"),
      .identPill("Q"),
      .word("together with a proof"),
      .identPill("p : P"),
      .word(". So"),
      .identPill("P"),
      .word("is a proposition we have assumed to be true, while"),
      .identPill("Q"),
      .word("may or may not be true."),
    ]),
    IntroParagraph(segments: [
      .word("Under these assumptions, either"),
      .identPill("P"),
      .word("or"),
      .identPill("Q"),
      .word("defines an element of"),
      .identPill("Prop"),
      .word(". Use the"),
      .tacticPill("exact"),
      .word("tactic to give one. Try"),
      .tacticPill("Retry"),
      .word("to solve this level in multiple ways."),
    ]),
  ],

  "typeworld-l06-typeoftypes": [
    IntroParagraph(segments: [
      .word("Lean has a built-in type of types denoted"),
      .identPill("Type"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("More precisely — to avoid a contradiction known as"),
      .emphasis("Russell's paradox"),
      .word("— Lean has a hierarchy of types of types"),
      .identPill("Type u"),
      .word("parametrized by"),
      .emphasis("universe levels"),
      .identPill("u"),
      .word(". The bare name"),
      .identPill("Type"),
      .word("is a synonym for"),
      .identPill("Type 0"),
      .word(", the smallest universe."),
    ]),
    IntroParagraph(segments: [
      .word("The goal is to define an element of"),
      .identPill("Type"),
      .word(". Note that"),
      .identPill("exact Type"),
      .word("does not work, because"),
      .identPill("Type"),
      .word("belongs to a larger universe."),
    ]),
    IntroParagraph(segments: [
      .word("We have introduced a type small enough to be an element of"),
      .identPill("Type"),
      .word(". Use it with"),
      .tacticPill("exact"),
      .word("to solve this level."),
    ]),
  ],

  "typeworld-l07-bosslevel": [
    IntroParagraph(segments: [
      .word("Each world ends with a"),
      .emphasis("Boss Level"),
      .word(", intended to be more challenging than the levels that came before."),
    ]),
    IntroParagraph(segments: [
      .word("It is not easy to design a challenging exercise involving only the tactics"),
      .tacticPill("assumption"),
      .word("and"),
      .tacticPill("exact"),
      .word(", but here is a puzzle you may find interesting."),
    ]),
    IntroParagraph(segments: [
      .word("Your task, like in the previous level, is to define an element in the type"),
      .identPill("Type"),
      .word(". The context contains assumptions which could potentially be used."),
    ]),
    IntroParagraph(segments: [
      .word("You are allowed, if you insist, to solve this level the same way as the previous one. But we challenge you to define a"),
      .emphasis("different"),
      .word("element of"),
      .identPill("Type"),
      .word("than the one you used before."),
    ]),
  ],

  "functionworld-l01-identityfunction": [
    IntroParagraph(segments: [
      .word("The"),
      .emphasis("introduction rule"),
      .word("for function types explains how functions may be constructed."),
    ]),
    IntroParagraph(segments: [
      .word("To define a function from"),
      .identPill("A"),
      .word("to"),
      .identPill("B"),
      .word("one has the following obligation: for an arbitrary element"),
      .identPill("x : A"),
      .word("— a potential"),
      .emphasis("input"),
      .word("— specify an element of type"),
      .identPill("B"),
      .word("— the corresponding"),
      .emphasis("output"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("When the goal is a function type"),
      .identPill("A → B"),
      .word(", start by typing"),
      .tacticPill("intro"),
      .word("to add an arbitrary element"),
      .identPill("x : A"),
      .word("to the context and update the goal to a term of type"),
      .identPill("B"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("The identity function, denoted"),
      .identPill("id : A → A"),
      .word(", is the function that carries any element"),
      .identPill("a : A"),
      .word("to itself. The goal in this level is to define this function."),
    ]),
  ],

  "functionworld-l02-usingfunctions": [
    IntroParagraph(segments: [
      .word("The"),
      .emphasis("elimination rule"),
      .word("for function types explains how functions can be used to define elements of other types."),
    ]),
    IntroParagraph(segments: [
      .word("Given a function"),
      .identPill("f : A → B"),
      .word("and any element"),
      .identPill("a : A"),
      .word(", you can apply"),
      .identPill("f"),
      .word("to"),
      .identPill("a"),
      .word("to obtain an element"),
      .identPill("f a : B"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Like many programming languages, Lean uses juxtaposition with a space in between to denote function application. So"),
      .identPill("f a"),
      .word("is the notation for the element of"),
      .identPill("B"),
      .word("obtained by applying"),
      .identPill("f"),
      .word("to"),
      .identPill("a"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("In this level the context contains"),
      .identPill("a : A"),
      .word("and"),
      .identPill("f : A → B"),
      .word(", and the goal is an element of type"),
      .identPill("B"),
      .word(". Use"),
      .tacticPill("exact"),
      .word("with the appropriate term."),
    ]),
  ],

  "functionworld-l03-usingfunctionsbackwards": [
    IntroParagraph(segments: [
      .word("The context and goal in this level are identical to the previous one. We have"),
      .identPill("f : A → B"),
      .word("and"),
      .identPill("a : A"),
      .word(", and the goal is to define an element of type"),
      .identPill("B"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Lean has another tactic called"),
      .tacticPill("apply"),
      .word("which can be used in the presence of a function to transform the goal. If"),
      .identPill("f : A → B"),
      .word("is in the context and the goal has type"),
      .identPill("B"),
      .word(", then"),
      .identPill("apply f"),
      .word("updates the goal to ask instead for an element of type"),
      .identPill("A"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("This proof strategy asks Lean to solve the initial goal by applying"),
      .identPill("f"),
      .word("to the element you provide next. Try using"),
      .tacticPill("apply"),
      .word("to solve this level."),
    ]),
  ],

  "functionworld-l04-composingfunctions": [
    IntroParagraph(segments: [
      .word("Given functions"),
      .identPill("f : A → B"),
      .word("and"),
      .identPill("g : B → C"),
      .word("there is a"),
      .emphasis("composite function"),
      .word("from"),
      .identPill("A"),
      .word("to"),
      .identPill("C"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("It is defined to send"),
      .identPill("x : A"),
      .word("first to"),
      .identPill("f x : B"),
      .word("and then to"),
      .identPill("g (f x) : C"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Can you solve this level in one line using"),
      .identPill("exact fun x ↦ ?"),
      .word("with the appropriate thing in place of the"),
      .identPill("?"),
      .word("?"),
    ]),
    IntroParagraph(segments: [
      .word("Alternatively, you can use"),
      .tacticPill("intro"),
      .word("together with"),
      .tacticPill("exact"),
      .word("or"),
      .tacticPill("apply"),
      .word("to define the function step by step."),
    ]),
  ],

  "functionworld-l05-constantfunctions": [
    IntroParagraph(segments: [
      .word("Given a term"),
      .identPill("a : A"),
      .word("and any type"),
      .identPill("B"),
      .word(", there is a function of type"),
      .identPill("B → A"),
      .word("which is"),
      .emphasis("constant"),
      .word("at"),
      .identPill("a"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("This means that for any input"),
      .identPill("x : B"),
      .word("the output is always the element"),
      .identPill("a : A"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("The formula for the constant function is"),
      .identPill("fun x ↦ a"),
      .word(". Since the output does not depend on the input, this can also be written"),
      .identPill("fun _ ↦ a"),
      .word(". Can you figure out how to define this function?"),
    ]),
  ],

  "functionworld-l06-multivariablefunctions": [
    IntroParagraph(segments: [
      .word("Function types can be iterated. Given types"),
      .identPill("A"),
      .word(","),
      .identPill("B"),
      .word(", and"),
      .identPill("C"),
      .word(", we may form the function types"),
      .identPill("(A → B) → C"),
      .word("and"),
      .identPill("A → (B → C)"),
      .word(". These are"),
      .emphasis("not"),
      .word("the same."),
    ]),
    IntroParagraph(segments: [
      .word("Elements of type"),
      .identPill("A → (B → C)"),
      .word("are"),
      .emphasis("multivariable functions"),
      .word("that take more than one input before returning an output. The simplified notation"),
      .identPill("A → B → C"),
      .word("abbreviates"),
      .identPill("A → (B → C)"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Given"),
      .identPill("f : A → B → C"),
      .word("and"),
      .identPill("a : A"),
      .word(",  then"),
      .identPill("f a : B → C"),
      .word("is a function from"),
      .identPill("B"),
      .word("to"),
      .identPill("C"),
      .word(", and given"),
      .identPill("b : B"),
      .word("we get"),
      .identPill("f a b : C"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("This level can be solved by starting with"),
      .tacticPill("exact"),
      .word(", with"),
      .tacticPill("apply"),
      .word(", or with"),
      .tacticPill("intro"),
      .word(". Try to find a different solution each time."),
    ]),
  ],

  "functionworld-l07-swappinginputs": [
    IntroParagraph(segments: [
      .word("Recall that an element of type"),
      .identPill("A → B → C"),
      .word("can be thought of as a function of two variables. Given"),
      .identPill("f : A → B → C"),
      .word(","),
      .identPill("a : A"),
      .word(", and"),
      .identPill("b : B"),
      .word(",  the term"),
      .identPill("f a b : C"),
      .word("applies"),
      .identPill("f"),
      .word("first to"),
      .identPill("a"),
      .word("and then to"),
      .identPill("b"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("From a function of type"),
      .identPill("A → B → C"),
      .word(", we can define a function of type"),
      .identPill("B → A → C"),
      .word("by exchanging the order of the inputs."),
    ]),
    IntroParagraph(segments: [
      .word("The goal here is a multivariable function type taking three inputs — of types"),
      .identPill("A → B → C"),
      .word(","),
      .identPill("B"),
      .word(", and"),
      .identPill("A"),
      .word(" — and returning an output of type"),
      .identPill("C"),
      .word(". You can start with"),
      .identPill("intro f b a"),
      .word("to introduce all three variables at once."),
    ]),
  ],

  "functionworld-l08-compositionrevisited": [
    IntroParagraph(segments: [
      .word("Recall that given"),
      .identPill("f : A → B"),
      .word("and"),
      .identPill("g : B → C"),
      .word("there is a composite function"),
      .identPill("g ∘ f : A → C"),
      .word(", which sends"),
      .identPill("a : A"),
      .word("first to"),
      .identPill("f a : B"),
      .word("and then to"),
      .identPill("g (f a) : C"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("The goal in this level is to define composition itself as a multivariable function between function types"),
      .identPill("(B → C) → (A → B) → (A → C)"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("We often think of composition as taking"),
      .identPill("g"),
      .word("and"),
      .identPill("f"),
      .word("to the composite"),
      .identPill("comp g f"),
      .word(". But it can also be thought of as a function taking"),
      .identPill("g"),
      .word(","),
      .identPill("f"),
      .word(", and"),
      .identPill("a : A"),
      .word("to the element"),
      .identPill("g (f a) : C"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("You can apply"),
      .tacticPill("intro"),
      .word("multiple times — for instance"),
      .identPill("intro g f"),
      .word("or"),
      .identPill("intro g f a"),
      .word(" — then close the goal with"),
      .tacticPill("exact"),
      .word("or"),
      .tacticPill("apply"),
      .word("."),
    ]),
  ],

  "functionworld-l09-evaluation": [
    IntroParagraph(segments: [
      .word("While an element of type"),
      .identPill("A → (B → C)"),
      .word("is a function of two variables, an element of type"),
      .identPill("(A → B) → C"),
      .word("is instead a function that takes a function"),
      .identPill("f : A → B"),
      .word("as input and returns an element of type"),
      .identPill("C"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("For example, given"),
      .identPill("a : A"),
      .word("we can define a function of type"),
      .identPill("(A → B) → B"),
      .word("called"),
      .emphasis("evaluation"),
      .word("at"),
      .identPill("a"),
      .word(": given"),
      .identPill("f : A → B"),
      .word(", return"),
      .identPill("f a : B"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Your task in this level is to define the evaluation function. Try starting with"),
      .tacticPill("intro"),
      .word("and finishing with"),
      .tacticPill("exact"),
      .word("."),
    ]),
  ],

  "functionworld-l10-bosslevel": [
    IntroParagraph(segments: [
      .word("We have reached the Boss Level of Function World, considerably more challenging than the Boss Level of Type World. Have fun with this."),
    ]),
    IntroParagraph(segments: [
      .word("We consider an arbitrary pair of types, called"),
      .identPill("V"),
      .word("and"),
      .identPill("F"),
      .word(" — for"),
      .emphasis("vector space"),
      .word("and"),
      .emphasis("field"),
      .word(" — because the function to be defined below has a connection to linear algebra that is not explained here."),
    ]),
    IntroParagraph(segments: [
      .word("Can you define a function of type"),
      .identPill("((((V → F) → F) → F) → F) → ((V → F) → F)"),
      .word("? You will need to combine"),
      .tacticPill("intro"),
      .word("and"),
      .tacticPill("apply"),
      .word("several times."),
    ]),
  ],

  "implicationworld-l01-byassumption": [
    IntroParagraph(segments: [
      .word("We warm up by revisiting our first theorem, already proven in Type World."),
    ]),
    IntroParagraph(segments: [
      .word("This theorem concerns an arbitrary proposition"),
      .identPill("P"),
      .word(". The hypothesis"),
      .identPill("p : P"),
      .word("can be thought of as a"),
      .emphasis("proof"),
      .word("that"),
      .identPill("P"),
      .word("is true. Our objective is to conclude that"),
      .identPill("P"),
      .word("is true."),
    ]),
    IntroParagraph(segments: [
      .word("This is true by assumption, and you can type"),
      .tacticPill("assumption"),
      .word("to tell Lean this. But it is a bit more precise to tell Lean this is true by the assumption"),
      .identPill("p"),
      .word(", which can be done by typing"),
      .identPill("exact p"),
      .word("."),
    ]),
  ],

  "implicationworld-l02-modusponens": [
    IntroParagraph(segments: [
      .word("We are now in the setting of two propositions"),
      .identPill("P"),
      .word("and"),
      .identPill("Q"),
      .word("with two hypotheses: a proof"),
      .identPill("p : P"),
      .word("and a proof"),
      .identPill("h : P → Q"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("It follows that"),
      .identPill("Q"),
      .word("is also true, and we can construct a proof by applying the hypothesis"),
      .identPill("h"),
      .word("to the proof"),
      .identPill("p"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("This line of reasoning has the Latin name"),
      .emphasis("modus ponens"),
      .word(". The tactic"),
      .tacticPill("apply"),
      .word("converts the goal"),
      .identPill("Q"),
      .word("into the simpler goal"),
      .identPill("P"),
      .word(", which can then be closed with"),
      .tacticPill("exact"),
      .word("."),
    ]),
  ],

  "implicationworld-l03-applyingimplication": [
    IntroParagraph(segments: [
      .word("We just proved modus ponens using"),
      .emphasis("backwards reasoning"),
      .word(": from"),
      .identPill("p : P"),
      .word("and"),
      .identPill("h : P → Q"),
      .word("we argued that"),
      .identPill("Q"),
      .word("is true."),
    ]),
    IntroParagraph(segments: [
      .word("Lean also has a syntax that lets us directly construct a proof of"),
      .identPill("Q"),
      .word("out of the proofs"),
      .identPill("p : P"),
      .word("and"),
      .identPill("h : P → Q"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("The proof"),
      .identPill("h"),
      .word("can be thought of as a"),
      .emphasis("function"),
      .word("that converts proofs of"),
      .identPill("P"),
      .word("into proofs of"),
      .identPill("Q"),
      .word(". We can apply"),
      .identPill("h"),
      .word("to"),
      .identPill("p"),
      .word("to obtain a proof of"),
      .identPill("Q"),
      .word("denoted"),
      .identPill("h p"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("You can solve this level — proving modus ponens again — by typing"),
      .identPill("exact h p"),
      .word("."),
    ]),
  ],

  "implicationworld-l04-composingimplication": [
    IntroParagraph(segments: [
      .word("Now we are in the setting of three propositions"),
      .identPill("P"),
      .word(","),
      .identPill("Q"),
      .word(", and"),
      .identPill("R"),
      .word("with hypotheses"),
      .identPill("p : P"),
      .word(","),
      .identPill("h1 : P → Q"),
      .word(", and"),
      .identPill("h2 : Q → R"),
      .word(". Our goal is to conclude that"),
      .identPill("R"),
      .word("is true."),
    ]),
    IntroParagraph(segments: [
      .word("This can be proven backwards using"),
      .tacticPill("apply"),
      .word("or forwards by directly constructing proofs out of the hypotheses."),
    ]),
    IntroParagraph(segments: [
      .word("It is also possible to work forwards with the"),
      .tacticPill("have"),
      .word("tactic, which is now in your library. Given"),
      .identPill("p : P"),
      .word("and"),
      .identPill("h1 : P → Q"),
      .word(", type"),
      .identPill("have q : Q := h1 p"),
      .word("to add a new proof"),
      .identPill("q : Q"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("The"),
      .tacticPill("have"),
      .word("tactic often makes proofs longer but easier to read. Practice using both directions to solve this level."),
    ]),
  ],

  "implicationworld-l05-provingimplication": [
    IntroParagraph(segments: [
      .word("To prove an implication"),
      .identPill("P → Q"),
      .word("one must give a construction of a proof of"),
      .identPill("Q"),
      .word("from a hypothesized proof of"),
      .identPill("P"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("In particular, to prove"),
      .identPill("P → Q"),
      .word("it suffices to assume that we have a proof"),
      .identPill("p : P"),
      .word(" — even if"),
      .identPill("P"),
      .word("is false and such a proof does not exist — in which case the new goal is to find a proof of"),
      .identPill("Q"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("When the goal has the form"),
      .identPill("P → Q"),
      .word(", type"),
      .identPill("intro p"),
      .word("to introduce"),
      .identPill("p : P"),
      .word("and update the goal to"),
      .identPill("Q"),
      .word(". You may also type just"),
      .tacticPill("intro"),
      .word("and let Lean generate the name."),
    ]),
    IntroParagraph(segments: [
      .word("In this level, we will see that"),
      .identPill("P → P"),
      .word("is true for any proposition"),
      .identPill("P"),
      .word("— even when"),
      .identPill("P"),
      .word("itself is false."),
    ]),
  ],

  "implicationworld-l06-provingimpliedassumption": [
    IntroParagraph(segments: [
      .word("To prove an implication"),
      .identPill("S → T"),
      .word("one needs to give a construction of a proof of"),
      .identPill("T"),
      .word("from a proof of"),
      .identPill("S"),
      .word(". It is not necessary to actually"),
      .emphasis("use"),
      .word("the assumption that"),
      .identPill("S"),
      .word("is true after introducing it."),
    ]),
    IntroParagraph(segments: [
      .word("In this level we consider propositions"),
      .identPill("P"),
      .word("and"),
      .identPill("Q"),
      .word("and assume that"),
      .identPill("P"),
      .word("is true. It follows that"),
      .identPill("Q → P"),
      .word("is true regardless of whether"),
      .identPill("Q"),
      .word("holds."),
    ]),
    IntroParagraph(segments: [
      .word("Start with"),
      .tacticPill("intro"),
      .word("to introduce a hypothesis you won't need, then finish with"),
      .tacticPill("exact"),
      .word("."),
    ]),
  ],

  "implicationworld-l07-provingassumedimplication": [
    IntroParagraph(segments: [
      .word("There are two ways to prove that"),
      .identPill("P → Q"),
      .word("under the assumption"),
      .identPill("h : P → Q"),
      .word(". Can you find them both?"),
    ]),
    IntroParagraph(segments: [
      .word("One approach is to start with"),
      .tacticPill("intro"),
      .word("to assume"),
      .identPill("p : P"),
      .word(", then"),
      .tacticPill("apply"),
      .word("the implication"),
      .identPill("h"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("The other is more direct: the goal"),
      .identPill("P → Q"),
      .word("is already in the context. The lesson is to pay attention to the big picture, namely exactly what you are being asked to prove under what hypotheses."),
    ]),
  ],

  "implicationworld-l08-transitivity": [
    IntroParagraph(segments: [
      .word("For propositions"),
      .identPill("P"),
      .word(","),
      .identPill("Q"),
      .word(", and"),
      .identPill("R"),
      .word(", the propositions"),
      .identPill("(P → Q) → R"),
      .word("and"),
      .identPill("P → (Q → R)"),
      .word("are not the same."),
    ]),
    IntroParagraph(segments: [
      .word("The first asserts that"),
      .identPill("R"),
      .word("is true assuming"),
      .identPill("P → Q"),
      .word(". The second asserts that"),
      .identPill("Q → R"),
      .word("is true assuming"),
      .identPill("P"),
      .word(", or equivalently that"),
      .identPill("R"),
      .word("is true under both"),
      .identPill("P"),
      .word("and"),
      .identPill("Q"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Statements of the second form are far more common, so the shorthand"),
      .identPill("P → Q → R"),
      .word("implicitly refers to"),
      .identPill("P → (Q → R)"),
      .word(". Explicit parentheses must be used for any other parenthesization."),
    ]),
    IntroParagraph(segments: [
      .word("Your objective is to prove the"),
      .emphasis("transitivity"),
      .word("of implication."),
    ]),
  ],

  "implicationworld-l09-modusponensagain": [
    IntroParagraph(segments: [
      .word("Modus ponens tells us that under hypotheses"),
      .identPill("p : P"),
      .word("and"),
      .identPill("h : P → Q"),
      .word(", the proposition"),
      .identPill("Q"),
      .word("is true."),
    ]),
    IntroParagraph(segments: [
      .word("The proof is given by"),
      .identPill("h p : Q"),
      .word(", the result of applying the proof"),
      .identPill("h"),
      .word("of the implication"),
      .identPill("P → Q"),
      .word("to the proof"),
      .identPill("p"),
      .word("of"),
      .identPill("P"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Can you see why"),
      .identPill("P → (P → Q) → Q"),
      .word("is another form of modus ponens? Start with"),
      .tacticPill("intro"),
      .word("twice and finish with"),
      .tacticPill("apply"),
      .word("or"),
      .tacticPill("exact"),
      .word("."),
    ]),
  ],

  "implicationworld-l10-bosslevel": [
    IntroParagraph(segments: [
      .word("We are now ready for the Boss Level of Implication World."),
    ]),
    IntroParagraph(segments: [
      .word("Multiple hypotheses can be introduced at once by writing"),
      .identPill("intro h1 h2 h3"),
      .word("etc. You might consider using names that help you remember which proposition each hypothesis proves."),
    ]),
    IntroParagraph(segments: [
      .word("While it is not necessary to solve this level, you may enjoy experimenting with the"),
      .tacticPill("have"),
      .word("tactic. The proof will chain many"),
      .tacticPill("apply"),
      .word("calls to walk the implications from"),
      .identPill("P"),
      .word("to"),
      .identPill("Z"),
      .word("."),
    ]),
  ],

  "productworld-l01-pairing": [
    IntroParagraph(segments: [
      .word("The introduction rule for product types tells us that elements of a product type"),
      .identPill("A × B"),
      .word("are formed by"),
      .emphasis("pairing"),
      .word("an element of"),
      .identPill("A"),
      .word("with an element of"),
      .identPill("B"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Given"),
      .identPill("a : A"),
      .word("and"),
      .identPill("b : B"),
      .word("there is a corresponding element"),
      .identPill("⟨a, b⟩ : A × B"),
      .word("— an"),
      .emphasis("ordered pair"),
      .word("whose first component is"),
      .identPill("a"),
      .word("and whose second component is"),
      .identPill("b"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("You can input this directly with"),
      .identPill("exact ⟨a, b⟩"),
      .word("using"),
      .identPill("\\<"),
      .word("and"),
      .identPill("\\>"),
      .word("for the angle brackets."),
    ]),
    IntroParagraph(segments: [
      .word("Alternatively, you can apply the"),
      .tacticPill("constructor"),
      .word("tactic, which splits the goal"),
      .identPill("A × B"),
      .word("into two subgoals, one of type"),
      .identPill("A"),
      .word("and one of type"),
      .identPill("B"),
      .word("."),
    ]),
  ],

  "productworld-l02-firstprojection": [
    IntroParagraph(segments: [
      .word("The elimination rules for product types tell us which elements can be constructed from an element"),
      .identPill("p : A × B"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("There are two: from"),
      .identPill("p : A × B"),
      .word("we may extract its first component"),
      .identPill("p.1 : A"),
      .word("(also written"),
      .identPill("p.fst"),
      .word(") and its second component"),
      .identPill("p.2 : B"),
      .word("(also written"),
      .identPill("p.snd"),
      .word(")."),
    ]),
    IntroParagraph(segments: [
      .word("These rules define"),
      .emphasis("projection functions"),
      .word("of types"),
      .identPill("A × B → A"),
      .word("and"),
      .identPill("A × B → B"),
      .word(". Your task is to define the first projection. Start with"),
      .tacticPill("intro"),
      .word("and finish with"),
      .tacticPill("exact"),
      .word("."),
    ]),
  ],

  "productworld-l03-secondprojection": [
    IntroParagraph(segments: [
      .word("The elimination rules for product types define"),
      .emphasis("projection functions"),
      .word("of types"),
      .identPill("A × B → A"),
      .word("and"),
      .identPill("A × B → B"),
      .word(", taking an element"),
      .identPill("p : A × B"),
      .word("to its corresponding component."),
    ]),
    IntroParagraph(segments: [
      .word("In Lean, the projections are denoted"),
      .identPill("p.1"),
      .word("and"),
      .identPill("p.2"),
      .word(", or equivalently"),
      .identPill("p.fst"),
      .word("and"),
      .identPill("p.snd"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Your task in this level is to define the"),
      .emphasis("second"),
      .word("projection function. Use"),
      .tacticPill("intro"),
      .word("then"),
      .tacticPill("exact"),
      .word("with the appropriate projection."),
    ]),
  ],

  "productworld-l04-symmetry": [
    IntroParagraph(segments: [
      .word("The product type comes with a function of type"),
      .identPill("A × B → B × A"),
      .word("which swaps the elements of an ordered pair."),
    ]),
    IntroParagraph(segments: [
      .word("This function can be defined by using the elimination rule for product types to map out of"),
      .identPill("A × B"),
      .word(", followed by the introduction rule to map into"),
      .identPill("B × A"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Concretely: introduce a variable"),
      .identPill("p : A × B"),
      .word(", project to its components"),
      .identPill("p.1 : A"),
      .word("and"),
      .identPill("p.2 : B"),
      .word(", then reassemble these into an element of"),
      .identPill("B × A"),
      .word(". Are function types symmetric? Why or why not?"),
    ]),
  ],

  "productworld-l05-associativity": [
    IntroParagraph(segments: [
      .word("Given three types"),
      .identPill("A"),
      .word(","),
      .identPill("B"),
      .word(", and"),
      .identPill("C"),
      .word(", the product construction may be iterated to define types"),
      .identPill("(A × B) × C"),
      .word("and"),
      .identPill("A × (B × C)"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("A term"),
      .identPill("p : (A × B) × C"),
      .word("has projections"),
      .identPill("p.1 : A × B"),
      .word("and"),
      .identPill("p.2 : C"),
      .word(", and then"),
      .identPill("p.1.1 : A"),
      .word(","),
      .identPill("p.1.2 : B"),
      .word(". A term"),
      .identPill("q : A × (B × C)"),
      .word("similarly has"),
      .identPill("q.1"),
      .word(","),
      .identPill("q.2.1"),
      .word(","),
      .identPill("q.2.2"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("By convention,"),
      .identPill("A × B × C"),
      .word("abbreviates"),
      .identPill("A × (B × C)"),
      .word(", and"),
      .identPill("⟨a, b, c⟩"),
      .word("abbreviates"),
      .identPill("⟨a, ⟨b, c⟩⟩"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Define a"),
      .emphasis("pair"),
      .word("of functions, one in each direction, witnessing that the two parenthesizations are closely related. Start with"),
      .tacticPill("constructor"),
      .word("to split the goal."),
    ]),
  ],

  "productworld-l06-currying": [
    IntroParagraph(segments: [
      .word("Consider a function"),
      .identPill("f : A × B → C"),
      .word("mapping out of a product. It takes an ordered pair built from"),
      .identPill("a : A"),
      .word("and"),
      .identPill("b : B"),
      .word("and returns"),
      .identPill("f ⟨a, b⟩ : C"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Recall that terms of type"),
      .identPill("g : A → B → C"),
      .word("are also functions of two variables, returning"),
      .identPill("g a b : C"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Both"),
      .identPill("A × B → C"),
      .word("and"),
      .identPill("A → B → C"),
      .word("provide a notion of function of two variables. The first takes a pair; the second takes inputs one at a time."),
    ]),
    IntroParagraph(segments: [
      .word("The process of converting a function of type"),
      .identPill("A × B → C"),
      .word("to one of type"),
      .identPill("A → B → C"),
      .word("is called"),
      .emphasis("currying"),
      .word(". Your task is to define the currying function."),
    ]),
  ],

  "productworld-l07-uncurrying": [
    IntroParagraph(segments: [
      .word("Both"),
      .identPill("A × B → C"),
      .word("and"),
      .identPill("A → B → C"),
      .word("provide a notion of function of two variables. The first takes a pair"),
      .identPill("⟨a, b⟩ : A × B"),
      .word("; the second takes"),
      .identPill("a : A"),
      .word("and returns a function"),
      .identPill("g a : B → C"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("The process of converting a function of type"),
      .identPill("A → B → C"),
      .word("to one of type"),
      .identPill("A × B → C"),
      .word("is called"),
      .emphasis("uncurrying"),
      .word(". Your task is to define the uncurrying function."),
    ]),
    IntroParagraph(segments: [
      .word("Start with"),
      .tacticPill("intro"),
      .word("to introduce the function and the pair, then build the output by projecting the pair into the two arguments of the function."),
    ]),
  ],

  "productworld-l08-componentfunctions": [
    IntroParagraph(segments: [
      .word("A function"),
      .identPill("f : A × B → C"),
      .word("out of a product can be regarded as a function of two variables. How should we think about a function"),
      .emphasis("into"),
      .word("a product?"),
    ]),
    IntroParagraph(segments: [
      .word("Consider"),
      .identPill("f : X → A × B"),
      .word(". From this we can define a pair of functions"),
      .identPill("X → A"),
      .word("and"),
      .identPill("X → B"),
      .word("that send"),
      .identPill("x : X"),
      .word("to"),
      .identPill("(f x).1"),
      .word("and"),
      .identPill("(f x).2"),
      .word("respectively."),
    ]),
    IntroParagraph(segments: [
      .word("These are called the"),
      .emphasis("component functions"),
      .word("associated to"),
      .identPill("f"),
      .word(". Your task is to define a function that extracts the component functions from a function into a product type. Use"),
      .tacticPill("intro"),
      .word("and"),
      .tacticPill("constructor"),
      .word("."),
    ]),
  ],

  "productworld-l09-universalproperty": [
    IntroParagraph(segments: [
      .word("We've seen that a function"),
      .identPill("f : X → A × B"),
      .word("decomposes into component functions"),
      .identPill("X → A"),
      .word("and"),
      .identPill("X → B"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Now we consider the reverse: from"),
      .identPill("g : X → A"),
      .word("and"),
      .identPill("h : X → B"),
      .word("with the same domain, we can combine them into a single function of type"),
      .identPill("X → A × B"),
      .word("whose component functions are"),
      .identPill("g"),
      .word("and"),
      .identPill("h"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("While not strictly necessary, you may try the"),
      .tacticPill("let"),
      .word("tactic, which is like"),
      .tacticPill("have"),
      .word("but creates elements of types rather than proofs of propositions. For example"),
      .identPill("let g : X → A := p.1"),
      .word("adds the first component of"),
      .identPill("p"),
      .word("to your context under the name"),
      .identPill("g"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("The"),
      .emphasis("universal property"),
      .word("of the product is the correspondence between functions"),
      .identPill("X → A × B"),
      .word("and pairs of functions"),
      .identPill("(X → A) × (X → B)"),
      .word("."),
    ]),
  ],

  "productworld-l10-bosslevel": [
    IntroParagraph(segments: [
      .word("The objective of this Boss Level is to define a function that takes five variables as inputs and has three outputs by combining four simpler functions."),
    ]),
    IntroParagraph(segments: [
      .word("This function is defined as a composite — in a much more complicated sense than we have seen thus far — of the given functions. Can you do it?"),
    ]),
    IntroParagraph(segments: [
      .word("The"),
      .tacticPill("let"),
      .word("tactic, now in your library, can help make partial progress. You can pull out each component"),
      .identPill("a"),
      .word(","),
      .identPill("b"),
      .word(","),
      .identPill("c"),
      .word(","),
      .identPill("d"),
      .word(","),
      .identPill("e"),
      .word("from the input pair before assembling the output."),
    ]),
  ],

  "conjunctionworld-l01-introducingand": [
    IntroParagraph(segments: [
      .word("To prove a conjunction"),
      .identPill("P ∧ Q"),
      .word("we need to supply a proof of both"),
      .identPill("P"),
      .word("and"),
      .identPill("Q"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("This expresses the introduction rule for the logical operation of conjunction."),
    ]),
    IntroParagraph(segments: [
      .word("Use the tactic"),
      .tacticPill("constructor"),
      .word("to break the goal"),
      .identPill("P ∧ Q"),
      .word("into two steps: first proving"),
      .identPill("P"),
      .word(", then proving"),
      .identPill("Q"),
      .word(". Alternatively, you can type"),
      .identPill("exact ⟨p, q⟩"),
      .word("directly."),
    ]),
  ],

  "conjunctionworld-l02-usingand": [
    IntroParagraph(segments: [
      .word("A hypothesis"),
      .identPill("h : P ∧ Q"),
      .word("provides explicit proofs of both"),
      .identPill("P"),
      .word("and"),
      .identPill("Q"),
      .word(", denoted in Lean by"),
      .identPill("h.1 : P"),
      .word("and"),
      .identPill("h.2 : Q"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Collectively, this expresses the pair of elimination rules for conjunction."),
    ]),
    IntroParagraph(segments: [
      .word("This level can be solved in two ways — using"),
      .tacticPill("constructor"),
      .word("with the two projections, or"),
      .tacticPill("exact"),
      .word("directly with"),
      .identPill("h"),
      .word(". Can you find them both?"),
    ]),
  ],

  "conjunctionworld-l03-symmetry": [
    IntroParagraph(segments: [
      .word("If"),
      .identPill("P ∧ Q"),
      .word("is true, then"),
      .identPill("Q ∧ P"),
      .word("is too. This is the proposition"),
      .identPill("P ∧ Q → Q ∧ P"),
      .word(", implicitly parenthesized as"),
      .identPill("(P ∧ Q) → (Q ∧ P)"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("In a compound proposition formed by iteratively applying logical connectives, the"),
      .emphasis("outermost"),
      .word("connective (applied last) often determines the overall proof strategy."),
    ]),
    IntroParagraph(segments: [
      .word("Start by identifying the outermost logical connective and use the tactic corresponding to its introduction rule:"),
      .tacticPill("intro"),
      .word("to assume the conjunction, then"),
      .tacticPill("constructor"),
      .word("to split into two subgoals."),
    ]),
  ],

  "conjunctionworld-l04-logicalequivalence": [
    IntroParagraph(segments: [
      .word("Two propositions"),
      .identPill("P"),
      .word("and"),
      .identPill("Q"),
      .word("are"),
      .emphasis("logically equivalent"),
      .word("if each implies the other. This can be expressed as the compound proposition"),
      .identPill("(P → Q) ∧ (Q → P)"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Because this notion appears frequently, we introduce"),
      .identPill("P ↔ Q"),
      .word("as a useful shorthand. The proposition"),
      .identPill("P ↔ Q"),
      .word("asserts that"),
      .identPill("P"),
      .word("is true"),
      .emphasis("if and only if"),
      .identPill("Q"),
      .word("is true. The symbol"),
      .identPill("↔"),
      .word("is typed using"),
      .identPill("\\iff"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Use"),
      .tacticPill("constructor"),
      .word("to split the iff into its two implications, then prove each direction using the symmetry argument from the previous level."),
    ]),
  ],

  "conjunctionworld-l05-associativity": [
    IntroParagraph(segments: [
      .word("For propositions"),
      .identPill("P"),
      .word(","),
      .identPill("Q"),
      .word(", and"),
      .identPill("R"),
      .word(","),
      .identPill("(P ∧ Q) ∧ R"),
      .word("is true if and only if"),
      .identPill("P ∧ (Q ∧ R)"),
      .word("is true."),
    ]),
    IntroParagraph(segments: [
      .word("Lean uses"),
      .identPill("P ∧ Q ∧ R"),
      .word("as shorthand for"),
      .identPill("P ∧ (Q ∧ R)"),
      .word(". Given"),
      .identPill("h : (P ∧ Q) ∧ R"),
      .word("we have"),
      .identPill("h.1.1 : P"),
      .word(","),
      .identPill("h.1.2 : Q"),
      .word(","),
      .identPill("h.2 : R"),
      .word(", while"),
      .identPill("k : P ∧ (Q ∧ R)"),
      .word("decomposes as"),
      .identPill("k.1"),
      .word(","),
      .identPill("k.2.1"),
      .word(","),
      .identPill("k.2.2"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Given proofs"),
      .identPill("p"),
      .word(","),
      .identPill("q"),
      .word(","),
      .identPill("r"),
      .word(",  Lean allows"),
      .identPill("⟨p, q, r⟩"),
      .word("as shorthand for"),
      .identPill("⟨p, ⟨q, r⟩⟩"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Your goal is to prove the associativity of conjunction."),
    ]),
  ],

  "conjunctionworld-l06-compoundimplication": [
    IntroParagraph(segments: [
      .word("Recall that implication is"),
      .emphasis("not"),
      .word("associative:"),
      .identPill("(P → Q) → R"),
      .word("and"),
      .identPill("P → (Q → R)"),
      .word("are not logically equivalent."),
    ]),
    IntroParagraph(segments: [
      .word("The shorthand"),
      .identPill("P → Q → R"),
      .word("abbreviates"),
      .identPill("P → (Q → R)"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("One reason mathematical statements of the form"),
      .identPill("P → (Q → R)"),
      .word("are more prevalent is that this is implied by"),
      .identPill("P ∧ Q → R"),
      .word(", implicitly parenthesized as"),
      .identPill("(P ∧ Q) → R"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Your task is to prove this implication. Start with"),
      .tacticPill("intro"),
      .word("twice, then"),
      .tacticPill("apply"),
      .word("the hypothesis to reduce the goal to a conjunction."),
    ]),
  ],

  "conjunctionworld-l07-morecompoundimplication": [
    IntroParagraph(segments: [
      .word("In the previous level we proved that"),
      .identPill("P ∧ Q → R"),
      .word("implies"),
      .identPill("P → Q → R"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Now we show the converse: that"),
      .identPill("P → Q → R"),
      .word("implies"),
      .identPill("P ∧ Q → R"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Introduce the conjunction with"),
      .tacticPill("intro"),
      .word(", then"),
      .tacticPill("apply"),
      .word("the hypothesis"),
      .identPill("h"),
      .word(" — since"),
      .identPill("h"),
      .word("is a compound implication, you will have two subgoals to close from the projections of the conjunction."),
    ]),
  ],

  "conjunctionworld-l08-curryingimplication": [
    IntroParagraph(segments: [
      .word("We now establish a logical equivalence between"),
      .identPill("P ∧ Q → R"),
      .word("and"),
      .identPill("P → Q → R"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("This is why implications of the form"),
      .identPill("P → (Q → R)"),
      .word("are so much more common than those of the form"),
      .identPill("(P → Q) → R"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("The two implications are referred to as"),
      .emphasis("currying"),
      .word("and"),
      .emphasis("uncurrying"),
      .word(", logical analogs of currying and uncurrying on functions of two variables. The proofs from the previous two levels, named"),
      .identPill("And.curry"),
      .word("and"),
      .identPill("And.uncurry"),
      .word(", are available in your theorem library."),
    ]),
  ],

  "conjunctionworld-l09-universalproperty": [
    IntroParagraph(segments: [
      .word("The task is to show another logical equivalence, this time between"),
      .identPill("(P → Q) ∧ (P → R)"),
      .word("and"),
      .identPill("P → Q ∧ R"),
      .word(", implicitly parenthesized as"),
      .identPill("P → (Q ∧ R)"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Recall that given"),
      .identPill("h : S → T"),
      .word("and"),
      .identPill("s : S"),
      .word(", we can form the proof"),
      .identPill("h s : T"),
      .word("by applying the implication. The proof"),
      .identPill("h"),
      .word("acts like a function that takes a proof"),
      .identPill("s : S"),
      .word("and returns a proof"),
      .identPill("h s : T"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Start with"),
      .tacticPill("constructor"),
      .word("to split the iff, then use"),
      .tacticPill("intro"),
      .word(","),
      .tacticPill("apply"),
      .word(", and the projection notation"),
      .identPill(".1"),
      .word(","),
      .identPill(".2"),
      .word("to assemble each direction."),
    ]),
  ],

  "conjunctionworld-l10-bosslevel": [
    IntroParagraph(segments: [
      .word("For the Boss Level of Conjunction World, the task is to prove a complicated implication chaining many conjunctions and implications together."),
    ]),
    IntroParagraph(segments: [
      .word("After introducing all of the allowed hypotheses, you may find it helpful to prove some intermediate propositions using the"),
      .tacticPill("have"),
      .word("tactic."),
    ]),
    IntroParagraph(segments: [
      .word("Good luck!"),
    ]),
  ],

  "coproductworld-l01-leftinclusion": [
    IntroParagraph(segments: [
      .word("For types"),
      .identPill("A"),
      .word("and"),
      .identPill("B"),
      .word(", the coproduct type"),
      .identPill("A ⊕ B"),
      .word("has two kinds of elements. The first can be thought of as copies of elements"),
      .identPill("a : A"),
      .word("included into the coproduct"),
      .emphasis("on the left"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Lean has a built-in function"),
      .identPill("Sum.inl : A → A ⊕ B"),
      .word(", now in your library. If the goal is to produce an element of"),
      .identPill("A ⊕ B"),
      .word(", typing"),
      .identPill("apply Sum.inl"),
      .word("converts this to a goal of producing an element of"),
      .identPill("A"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("The tactic"),
      .tacticPill("left"),
      .word("has the same effect. When the goal is a coproduct type"),
      .identPill("A ⊕ B"),
      .word(",  using"),
      .tacticPill("left"),
      .word("tells Lean that you plan to provide an element of type"),
      .identPill("A"),
      .word(", which will then be included into"),
      .identPill("A ⊕ B"),
      .word("via"),
      .identPill("Sum.inl"),
      .word("."),
    ]),
  ],

  "coproductworld-l02-rightinclusion": [
    IntroParagraph(segments: [
      .word("The coproduct type"),
      .identPill("A ⊕ B"),
      .word("has a second kind of element: copies of elements"),
      .identPill("b : B"),
      .word("included into the coproduct"),
      .emphasis("on the right"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Lean has a built-in function"),
      .identPill("Sum.inr : B → A ⊕ B"),
      .word(", now in your library. The tactic"),
      .tacticPill("right"),
      .word("converts a goal of"),
      .identPill("A ⊕ B"),
      .word("into a goal of"),
      .identPill("B"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Note that"),
      .identPill("Sum.inl"),
      .word("and"),
      .identPill("Sum.inr"),
      .word("from"),
      .identPill("A → A ⊕ A"),
      .word("are"),
      .emphasis("different functions"),
      .word("(provided"),
      .identPill("A"),
      .word("has at least one element), in a way we will make precise later."),
    ]),
  ],

  "coproductworld-l03-componentfunctions": [
    IntroParagraph(segments: [
      .word("Consider a function"),
      .identPill("f : A ⊕ B → C"),
      .word("mapping out of a coproduct type."),
    ]),
    IntroParagraph(segments: [
      .word("By composing with"),
      .identPill("Sum.inl"),
      .word("we obtain a function"),
      .identPill("g : A → C"),
      .word(", and by composing with"),
      .identPill("Sum.inr"),
      .word("we obtain"),
      .identPill("h : B → C"),
      .word(". These are the two"),
      .emphasis("component functions"),
      .word("associated to"),
      .identPill("f"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Since a single function of type"),
      .identPill("A ⊕ B → C"),
      .word("decomposes into a pair of functions, we can define an operation of type"),
      .identPill("(A ⊕ B → C) → (A → C) × (B → C)"),
      .word(". Your task is to define this operation. Use"),
      .tacticPill("intro"),
      .word("and"),
      .tacticPill("constructor"),
      .word("."),
    ]),
  ],

  "coproductworld-l04-universalproperty": [
    IntroParagraph(segments: [
      .word("Conversely, given any pair of functions"),
      .identPill("g : A → C"),
      .word("and"),
      .identPill("h : B → C"),
      .word(", we can build a single function of type"),
      .identPill("A ⊕ B → C"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("This function is defined by introducing"),
      .identPill("x : A ⊕ B"),
      .word("and splitting into two cases: when"),
      .identPill("x"),
      .word("is"),
      .identPill("Sum.inl a"),
      .word("we return"),
      .identPill("g a : C"),
      .word(", and when"),
      .identPill("x"),
      .word("is"),
      .identPill("Sum.inr b"),
      .word("we return"),
      .identPill("h b : C"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("The"),
      .tacticPill("cases"),
      .word("tactic asks Lean to consider both forms of"),
      .identPill("x"),
      .word(". The"),
      .tacticPill("rcases"),
      .word("tactic is similar but lets you name the elements:"),
      .identPill("rcases x with a | b"),
      .word("gives you"),
      .identPill("a : A"),
      .word("in the first case and"),
      .identPill("b : B"),
      .word("in the second."),
    ]),
  ],

  "coproductworld-l05-symmetry": [
    IntroParagraph(segments: [
      .word("The coproduct type, like the product type, is"),
      .emphasis("symmetric"),
      .word(", and has a canonical map of type"),
      .identPill("A ⊕ B → B ⊕ A"),
      .word(". Your task is to define it."),
    ]),
    IntroParagraph(segments: [
      .word("Use the elimination rule for coproducts ("),
      .tacticPill("cases"),
      .word("or"),
      .tacticPill("rcases"),
      .word(") to map"),
      .emphasis("out of"),
      .identPill("A ⊕ B"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Then use the introduction rules ("),
      .tacticPill("left"),
      .word("and"),
      .tacticPill("right"),
      .word(") to map"),
      .emphasis("into"),
      .identPill("B ⊕ A"),
      .word("."),
    ]),
  ],

  "coproductworld-l06-associativity": [
    IntroParagraph(segments: [
      .word("Given three types"),
      .identPill("A"),
      .word(","),
      .identPill("B"),
      .word(", and"),
      .identPill("C"),
      .word(", the coproduct construction may be iterated to define"),
      .identPill("(A ⊕ B) ⊕ C"),
      .word("and"),
      .identPill("A ⊕ (B ⊕ C)"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Both types have three cases of elements — from"),
      .identPill("a : A"),
      .word(","),
      .identPill("b : B"),
      .word(", or"),
      .identPill("c : C"),
      .word(" — but the notation depends on the parenthesization. For example,"),
      .identPill("b : B"),
      .word("includes as"),
      .identPill("Sum.inl (Sum.inr b)"),
      .word("on the left and"),
      .identPill("Sum.inr (Sum.inl b)"),
      .word("on the right."),
    ]),
    IntroParagraph(segments: [
      .word("By convention,"),
      .identPill("A ⊕ B ⊕ C"),
      .word("abbreviates"),
      .identPill("A ⊕ (B ⊕ C)"),
      .word(". For"),
      .identPill("x : A ⊕ B ⊕ C"),
      .word(", the pattern"),
      .identPill("rcases x with a | b | c"),
      .word("splits into all three cases at once. For"),
      .identPill("y : (A ⊕ B) ⊕ C"),
      .word(", use"),
      .identPill("rcases y with (a | b) | c"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Define a pair of functions going in each direction. Start with"),
      .tacticPill("constructor"),
      .word("to split the product."),
    ]),
  ],

  "coproductworld-l07-distributivity": [
    IntroParagraph(segments: [
      .word("How should we think about an element of type"),
      .identPill("x : A × (B ⊕ C)"),
      .word("?"),
    ]),
    IntroParagraph(segments: [
      .word("Since"),
      .identPill("x"),
      .word("is a pair, it has the form"),
      .identPill("⟨y, z⟩"),
      .word("with"),
      .identPill("y : A"),
      .word("and"),
      .identPill("z : B ⊕ C"),
      .word(". And"),
      .identPill("z"),
      .word("comes either from"),
      .identPill("b : B"),
      .word("or from"),
      .identPill("c : C"),
      .word(" — so"),
      .identPill("x"),
      .word("comes either from"),
      .identPill("A × B"),
      .word("or"),
      .identPill("A × C"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("This explains the"),
      .emphasis("distributivity"),
      .word("of products over coproducts, encoded as a pair of functions between"),
      .identPill("A × (B ⊕ C)"),
      .word("and"),
      .identPill("(A × B) ⊕ (A × C)"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Use the context and goal at each stage to guide you. Combine"),
      .tacticPill("intro"),
      .word(","),
      .tacticPill("rcases"),
      .word(","),
      .tacticPill("constructor"),
      .word(","),
      .tacticPill("left"),
      .word(", and"),
      .tacticPill("right"),
      .word("appropriately."),
    ]),
  ],

  "coproductworld-l08-bosslevel": [
    IntroParagraph(segments: [
      .word("For the Boss Level, your task is to:"),
    ]),
    IntroParagraph(segments: [
      .word("First, break apart a function from a coproduct type into a product type into"),
      .emphasis("four"),
      .word("separate component functions of types"),
      .identPill("A → C"),
      .word(","),
      .identPill("B → C"),
      .word(","),
      .identPill("A → D"),
      .word(", and"),
      .identPill("B → D"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Then, conversely, reassemble four such component functions into a single function from the coproduct to the product."),
    ]),
    IntroParagraph(segments: [
      .word("Good luck!"),
    ]),
  ],

  "disjunctionworld-l01-introducingor": [
    IntroParagraph(segments: [
      .word("To prove a disjunction"),
      .identPill("P ∨ Q"),
      .word("it suffices to supply a proof of either"),
      .identPill("P"),
      .word("or of"),
      .identPill("Q"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Under the hypothesis that"),
      .identPill("P"),
      .word("and"),
      .identPill("Q"),
      .word("are both true, there are two ways to prove"),
      .identPill("P ∨ Q"),
      .word(": one using"),
      .identPill("p : P"),
      .word("and one using"),
      .identPill("q : Q"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Note that"),
      .identPill("exact p"),
      .word("or"),
      .identPill("exact q"),
      .word("on their own won't work — these prove the wrong proposition."),
    ]),
    IntroParagraph(segments: [
      .word("Type"),
      .tacticPill("left"),
      .word("to tell Lean you'd like to prove the left proposition, or type"),
      .tacticPill("right"),
      .word("to prove the right. Alternatively, apply either of the implications"),
      .identPill("Or.inl"),
      .word("and"),
      .identPill("Or.inr"),
      .word(" directly."),
    ]),
  ],

  "disjunctionworld-l02-andimpliesor": [
    IntroParagraph(segments: [
      .word("The proposition"),
      .identPill("P ∧ Q"),
      .word("is"),
      .emphasis("stronger"),
      .word("than"),
      .identPill("P ∨ Q"),
      .word(" — the implication"),
      .identPill("P ∧ Q → P ∨ Q"),
      .word("is true in general, but the converse"),
      .identPill("P ∨ Q → P ∧ Q"),
      .word("does not necessarily hold."),
    ]),
    IntroParagraph(segments: [
      .word("The implication holds because mathematical \"or\" is"),
      .emphasis("inclusive"),
      .word(": if both"),
      .identPill("P"),
      .word("and"),
      .identPill("Q"),
      .word("are true, then"),
      .identPill("P ∨ Q"),
      .word("is true — and in fact can be proven in two different ways."),
    ]),
    IntroParagraph(segments: [
      .word("Start with"),
      .tacticPill("intro"),
      .word(", then choose"),
      .tacticPill("left"),
      .word("or"),
      .tacticPill("right"),
      .word("and supply the appropriate projection of the conjunction."),
    ]),
  ],

  "disjunctionworld-l03-usingor": [
    IntroParagraph(segments: [
      .word("Given a hypothesis"),
      .identPill("h : P ∨ Q"),
      .word(", we know that"),
      .emphasis("either"),
      .identPill("P"),
      .word("or"),
      .identPill("Q"),
      .word("is true. But we don't know"),
      .emphasis("which"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("To use such a hypothesis to prove some other proposition"),
      .identPill("R"),
      .word(", we need proofs that cover both cases:"),
      .identPill("P → R"),
      .word("and"),
      .identPill("Q → R"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Type"),
      .tacticPill("cases"),
      .word("on"),
      .identPill("h"),
      .word("to ask Lean to consider both cases. Or use"),
      .identPill("rcases h with p | q"),
      .word("to name the hypotheses yourself."),
    ]),
    IntroParagraph(segments: [
      .word("This strategy should be reminiscent of defining a function out of a coproduct type"),
      .identPill("A ⊕ B"),
      .word("— the same tactics apply. In this level, use proof by cases to show that disjunction is symmetric."),
    ]),
  ],

  "disjunctionworld-l04-symmetry": [
    IntroParagraph(segments: [
      .word("We can improve our understanding of the symmetry of disjunction as follows: for propositions"),
      .identPill("P"),
      .word("and"),
      .identPill("Q"),
      .word(","),
      .identPill("P ∨ Q"),
      .word("is true if and only if"),
      .identPill("Q ∨ P"),
      .word("is true."),
    ]),
    IntroParagraph(segments: [
      .word("To prove this, you might find it useful to use the theorem"),
      .identPill("Or.symm"),
      .word("from the previous level, which is now in your library."),
    ]),
    IntroParagraph(segments: [
      .word("Use"),
      .tacticPill("constructor"),
      .word("to split the iff, then close both directions — possibly by the same one-line proof."),
    ]),
  ],

  "disjunctionworld-l05-universalproperty": [
    IntroParagraph(segments: [
      .word("What must be true in order to have"),
      .identPill("P ∨ Q → R"),
      .word("?"),
    ]),
    IntroParagraph(segments: [
      .word("If"),
      .identPill("P ∨ Q → R"),
      .word("is true, then"),
      .identPill("P → R"),
      .word("is true (because"),
      .identPill("P"),
      .word("implies"),
      .identPill("P ∨ Q"),
      .word(" which implies"),
      .identPill("R"),
      .word("), and similarly"),
      .identPill("Q → R"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Conversely, if"),
      .emphasis("both"),
      .identPill("P → R"),
      .word("and"),
      .identPill("Q → R"),
      .word("are true, then"),
      .identPill("P ∨ Q → R"),
      .word("is true by proof by cases."),
    ]),
    IntroParagraph(segments: [
      .word("The aim is to establish the logical equivalence between"),
      .identPill("P ∨ Q → R"),
      .word("and"),
      .identPill("(P → R) ∧ (Q → R)"),
      .word(". This captures the"),
      .emphasis("universal property"),
      .word("of disjunction."),
    ]),
  ],

  "disjunctionworld-l06-associativity": [
    IntroParagraph(segments: [
      .word("For propositions"),
      .identPill("P"),
      .word(","),
      .identPill("Q"),
      .word(", and"),
      .identPill("R"),
      .word(","),
      .identPill("(P ∨ Q) ∨ R"),
      .word("holds if and only if"),
      .identPill("P ∨ (Q ∨ R)"),
      .word("holds."),
    ]),
    IntroParagraph(segments: [
      .word("As with the other connectives, Lean uses"),
      .identPill("P ∨ Q ∨ R"),
      .word("as shorthand for"),
      .identPill("P ∨ (Q ∨ R)"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Given"),
      .identPill("h₁ : (P ∨ Q) ∨ R"),
      .word(", you can split into the three underlying cases at once with"),
      .identPill("rcases h₁ with (p | q) | r"),
      .word(". Given"),
      .identPill("h₂ : P ∨ Q ∨ R"),
      .word(", use"),
      .identPill("rcases h₂ with p | q | r"),
      .word("."),
    ]),
    IntroParagraph(segments: [
      .word("Aside: typing"),
      .identPill("\\7"),
      .word("(or any digit) produces a subscript like"),
      .identPill("₇"),
      .word(" — handy for numbered variable names."),
    ]),
  ],

  "disjunctionworld-l07-distributivity": [
    IntroParagraph(segments: [
      .word("What does it mean if"),
      .identPill("P ∧ (Q ∨ R)"),
      .word("holds?"),
    ]),
    IntroParagraph(segments: [
      .word("Then certainly"),
      .identPill("P"),
      .word("is true and also"),
      .identPill("Q ∨ R"),
      .word("is true. So we can conclude that either"),
      .identPill("P ∧ Q"),
      .word("is true or"),
      .identPill("P ∧ R"),
      .word("is true, demonstrating one of the implications in the following logical equivalence."),
    ]),
    IntroParagraph(segments: [
      .word("This level proves that conjunction"),
      .emphasis("distributes"),
      .word("over disjunction:"),
      .identPill("P ∧ (Q ∨ R) ↔ (P ∧ Q) ∨ (P ∧ R)"),
      .word("."),
    ]),
  ],

  "disjunctionworld-l08-moredistributivity": [
    IntroParagraph(segments: [
      .word("A more involved form of distributivity is also true."),
    ]),
    IntroParagraph(segments: [
      .word("If"),
      .identPill("P ∨ Q"),
      .word("holds and"),
      .identPill("R ∨ S"),
      .word("holds, then at least one of the four conjunctions"),
      .identPill("P ∧ R"),
      .word(","),
      .identPill("P ∧ S"),
      .word(","),
      .identPill("Q ∧ R"),
      .word(",  or"),
      .identPill("Q ∧ S"),
      .word("holds."),
    ]),
    IntroParagraph(segments: [
      .word("Conversely, if any of these four conjunctions holds, then"),
      .identPill("P ∨ Q"),
      .word("holds and"),
      .identPill("R ∨ S"),
      .word("holds. Demonstrate the logical equivalence — the patterns"),
      .identPill("rcases h with ⟨p | q, r | s⟩"),
      .word("and"),
      .identPill("rcases h with pr | ps | qr | qs"),
      .word("may help."),
    ]),
  ],

  "disjunctionworld-l09-bosslevel": [
    IntroParagraph(segments: [
      .word("We have now reached the Boss Level of Disjunction World."),
    ]),
    IntroParagraph(segments: [
      .word("This level illustrates that proofs by cases can be somewhat delicate. You will need to combine"),
      .tacticPill("intro"),
      .word(","),
      .tacticPill("rcases"),
      .word(","),
      .tacticPill("apply"),
      .word(", and"),
      .tacticPill("have"),
      .word("to push proofs forward through several layers of implications and conjunctions."),
    ]),
    IntroParagraph(segments: [
      .word("Have fun!"),
    ]),
  ],
]
