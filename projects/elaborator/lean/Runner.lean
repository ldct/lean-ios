import Lean.Elab.Frontend
import Lean.Elab.Import
import Lean.Language.Lean
import Lean.Util.Path

open Lean Elab

private def formatMessages (messages : MessageLog) : IO String := do
  let lines ← messages.toList.mapM (m := BaseIO) Message.toString
  "\n\n".intercalate lines |> pure

private def collectMessages (snap : Language.SnapshotTree) : MessageLog :=
  snap.getAll.foldl (init := MessageLog.empty) fun messages snapshot =>
    messages ++ snapshot.diagnostics.msgLog

@[export checkLeanSource]
def checkLeanSource (bundleRoot : @& String) (input : @& String) : IO String := do
  try
    searchPathRef.set [System.FilePath.mk bundleRoot / "lib" / "lean"]
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
    let snap ← Language.Lean.process setup none { inputCtx with }
    let rendered ← snap
      |> Language.toSnapshotTree
      |> collectMessages
      |> formatMessages
    pure rendered
  catch e =>
    pure s!"{e}"
