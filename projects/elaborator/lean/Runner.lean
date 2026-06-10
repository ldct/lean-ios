import Lean.Elab.Frontend
import Lean.Elab.Import
import Lean.Language.Lean
import Lean.Server.InfoUtils
import Lean.Util.Path
import Lean.Widget.InteractiveGoal

open Lean Elab

private def collectMessages (snap : Language.SnapshotTree) : MessageLog :=
  snap.getAll.foldl (init := MessageLog.empty) fun messages snapshot =>
    messages ++ snapshot.diagnostics.msgLog

private def collectInfoTrees (snap : Language.SnapshotTree) : Array InfoTree :=
  snap.getAll.foldl (init := #[]) fun acc s =>
    match s.infoTree? with
    | some t => acc.push t
    | none => acc

private def findDoneInfo? (tree : InfoTree) : Option (ContextInfo × TacticInfo) :=
  tree.foldInfo (init := none) fun ctx info acc =>
    match acc with
    | some _ => acc
    | none =>
      match info with
      | .ofTacticInfo ti =>
        if ti.stx.getKind == ``Lean.Parser.Tactic.done then some (ctx, ti) else none
      | _ => none

private def findDoneInTrees (trees : Array InfoTree) : Option (ContextInfo × TacticInfo) :=
  trees.foldl (init := none) fun acc t =>
    match acc with
    | some _ => acc
    | none => findDoneInfo? t

private def severityName : MessageSeverity → String
  | .information => "info"
  | .warning => "warning"
  | .error => "error"

private def diagnosticToJson (m : Message) : IO Json := do
  let msg ← m.data.toString
  return Json.mkObj [
    ("line", Json.num m.pos.line),
    ("column", Json.num m.pos.column),
    ("severity", Json.str (severityName m.severity)),
    ("message", Json.str msg)
  ]

private def hypothesisToJson (h : Widget.InteractiveHypothesisBundle) : Json :=
  Json.mkObj [
    ("names", Json.arr (h.names.map Json.str)),
    ("type", Json.str h.type.stripTags)
  ]

private def interactiveGoalToJson (g : Widget.InteractiveGoal) : Json :=
  Json.mkObj [
    ("caseTag", g.userName?.elim Json.null Json.str),
    ("hypotheses", Json.arr (g.hyps.map hypothesisToJson)),
    ("target", Json.str g.type.stripTags)
  ]

private def collectGoals (ctx : ContextInfo) (ti : TacticInfo) : IO (Array Widget.InteractiveGoal) := do
  let ctx' := { ctx with mctx := ti.mctxBefore }
  ctx'.runMetaM {} do
    ti.goalsBefore.toArray.mapM Widget.goalToInteractive

private def errorResult (msg : String) : Json :=
  Json.mkObj [
    ("diagnostics", Json.arr #[Json.mkObj [
      ("line", Json.num 0),
      ("column", Json.num 0),
      ("severity", Json.str "error"),
      ("message", Json.str msg)
    ]]),
    ("goals", Json.arr #[]),
    ("complete", Json.bool false)
  ]

/--
Snapshot of the previous `checkLeanSource` run, passed back to `Language.Lean.process` so it can
reuse the imported environment when the header is unchanged. Without reuse, every check re-imports
the whole closure while the previous run's compacted regions are still mapped, so olean loading
falls back to heap copies that accumulate until reads fail on device.
-/
private initialize lastSnapRef : IO.Ref (Option Language.Lean.InitialSnapshot) ← IO.mkRef none

def checkLeanSourceAtPaths (searchPath : List System.FilePath) (input : String) : IO String := do
  try
    unsafe enableInitializersExecution
    searchPathRef.set searchPath
    let opts := Options.empty
    let inputCtx := Parser.mkInputContext input "<input>"
    let setup stx := do
      return .ok {
        imports := stx.imports
        isModule := stx.isModule
        mainModuleName := `LeanIOSElabExampleInput
        opts
        trustLevel := 0
        plugins := #[]
      }
    let old? ← lastSnapRef.get
    let snap ← Language.Lean.process setup old? { inputCtx with }
    lastSnapRef.set (some snap)
    let snaps := Language.toSnapshotTree snap
    let messages := collectMessages snaps
    let trees := collectInfoTrees snaps
    let doneInfo? := findDoneInTrees trees
    let donePos? := doneInfo?.bind fun (_, ti) => ti.stx.getPos?
    let donePosition? := donePos?.map inputCtx.fileMap.toPosition
    let kept := messages.toList.filter fun m =>
      match donePosition? with
      | some p => m.pos != p
      | none => true
    let diags ← kept.mapM diagnosticToJson
    let goals ← match doneInfo? with
      | some (ctx, ti) => collectGoals ctx ti
      | none => pure #[]
    let complete := doneInfo?.isSome && goals.isEmpty
    let result := Json.mkObj [
      ("diagnostics", Json.arr diags.toArray),
      ("goals", Json.arr (goals.map interactiveGoalToJson)),
      ("complete", Json.bool complete)
    ]
    pure result.compress
  catch e =>
    pure (errorResult s!"{e}").compress

@[export checkLeanSource]
def checkLeanSource (bundleRoot : String) (input : String) : IO String :=
  checkLeanSourceAtPaths [System.FilePath.mk bundleRoot / "lib" / "lean"] input
