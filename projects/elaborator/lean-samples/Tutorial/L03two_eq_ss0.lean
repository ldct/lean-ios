import Game.MyNat.Definition
import Game.MyNat.TutorialLemmas

namespace MyNat

example : 2 = succ (succ 0) := by
  rewrite [two_eq_succ_one]
  rewrite [one_eq_succ_zero]
  rfl
