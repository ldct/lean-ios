import Runner

def knownGoodScript : String :=
  "import Lean\n\n" ++
  "#check Nat.succ\n\n" ++
  "example : 1 = 1 := rfl\n\n" ++
  "def foo (n : Nat) : Nat := n + 1\n\n" ++
  "#eval foo 1\n"

def importBatteriesScript : String := "import Batteries\n"

def batteriesRBMapScript : String :=
  "import Batteries\n" ++
  "open Batteries\n" ++
  "def m : RBMap String Nat compare := (RBMap.empty.insert \"x\" 42).insert \"y\" 7\n" ++
  "#eval m.find? \"x\"\n" ++
  "#eval m.size\n"

def cleanProofScript : String :=
  "example {A : Type} (a : A) : A := by\n  exact a\n  done\n"

def sorryProofScript : String :=
  "example {A : Type} (a : A) : A := by\n  sorry\n  done\n"

def errorTacticScript : String :=
  "example {A : Type} (a : A) : A := by\n  exact b\n  done\n"

def deriveLeanLibDir : IO System.FilePath := do
  if let some d ← IO.getEnv "TEST_LEAN_LIB_DIR" then
    return System.FilePath.mk d
  let out ← IO.Process.run { cmd := "lean", args := #["--print-libdir"] }
  return System.FilePath.mk out.trimAscii.toString

def runCase (name input : String) (searchPath : List System.FilePath) : IO Bool := do
  IO.println s!"=== {name} ==="
  let output ← checkLeanSourceAtPaths searchPath input
  IO.println output
  let hasError := (output.splitOn "error:").length > 1
  if hasError then
    IO.eprintln s!"FAIL [{name}]: output contains 'error:'"
  else
    IO.println s!"PASS [{name}]"
  return !hasError

def runCompletenessCase (name input : String) (expected : Bool) (searchPath : List System.FilePath) : IO Bool := do
  IO.println s!"=== {name} ==="
  let output ← checkLeanSourceAtPaths searchPath input
  IO.println output
  let expectedField := s!"\"complete\":{expected}"
  if (output.splitOn expectedField).length > 1 then
    IO.println s!"PASS [{name}]"
    return true
  else
    IO.eprintln s!"FAIL [{name}]: expected {expectedField}"
    return false

def main : IO UInt32 := do
  let leanLib ← deriveLeanLibDir
  IO.println s!"leanLib = {leanLib}"
  let mut ok := true
  ok := (← runCase "known-good (master)" knownGoodScript [leanLib]) && ok
  ok := (← runCompletenessCase "complete: clean solve" cleanProofScript true [leanLib]) && ok
  ok := (← runCompletenessCase "not complete: sorry" sorryProofScript false [leanLib]) && ok
  ok := (← runCompletenessCase "not complete: erroring tactic" errorTacticScript false [leanLib]) && ok
  if let some battLib ← IO.getEnv "TEST_BATTERIES_LIB_DIR" then
    let battPath := System.FilePath.mk battLib
    IO.println s!"batteriesLib = {battPath}"
    ok := (← runCase "import Batteries" importBatteriesScript [leanLib, battPath]) && ok
    ok := (← runCase "Batteries.RBMap" batteriesRBMapScript [leanLib, battPath]) && ok
  else
    IO.eprintln "SKIP [import Batteries]: TEST_BATTERIES_LIB_DIR not set"
    ok := false
  return if ok then 0 else 1
