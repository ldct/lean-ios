import Game.MyNat.TutorialLemmas

namespace MyNat

example : 2 = succ (succ 0) := by
  rewrite [← one_eq_succ_zero]
  rewrite [← two_eq_succ_one]
  rfl
