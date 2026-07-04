import Game.MyNat.Addition
import Game.Levels.Tutorial.L07add_succ

namespace MyNat

example : (2 : ℕ) + 2 = 4 := by
  nth_rewrite 2 [two_eq_succ_one]
  rewrite [add_succ]
  rewrite [one_eq_succ_zero]
  rewrite [add_succ]
  rewrite [add_zero]
  rewrite [four_eq_succ_three]
  rewrite [three_eq_succ_two]
  rfl
