import Game.MyNat.Addition
import Game.Levels.Tutorial.L03two_eq_ss0

namespace MyNat

example (n : ℕ) : succ n = n + 1 := by
  rewrite [one_eq_succ_zero]
  rewrite [add_succ]
  rewrite [add_zero]
  rfl
