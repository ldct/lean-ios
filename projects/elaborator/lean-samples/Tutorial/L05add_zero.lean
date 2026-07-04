import Game.MyNat.Addition

namespace MyNat

example (a b c : ℕ) : a + (b + 0) + (c + 0) = a + b + c := by
  rewrite [add_zero]
  rewrite [add_zero]
  rfl
