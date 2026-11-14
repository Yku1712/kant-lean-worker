/- SheafAxioms.lean
   Formal skeleton for ERDFa sheaf gluing and CRT uniqueness.
-/

namespace ERDFa

/-- A numeric section: a value at each modular coordinate. -/
def Section := Nat → Nat

/-- Sheaf gluing uniqueness. -/
theorem glue_unique (s t : Section) (domL domR : Nat → Prop)
    (u v : Section)
    (huL : ∀ x, domL x → u x = s x)
    (huR : ∀ x, domR x → u x = t x)
    (hvL : ∀ x, domL x → v x = s x)
    (hvR : ∀ x, domR x → v x = t x) :
    ∀ x, (domL x ∨ domR x) → u x = v x := by
  intro x hx
  rcases hx with hL | hR
  · rw [huL x hL, hvL x hL]
  · rw [huR x hR, hvR x hR]

/-- CRT Uniqueness for moduli 71, 59, 47. -/
theorem crt_unique (x y : Nat)
    (hx : x < 71 * 59 * 47) (hy : y < 71 * 59 * 47)
    (h71 : x % 71 = y % 71)
    (h59 : x % 59 = y % 59)
    (h47 : x % 47 = y % 47) :
    x = y := by
  omega

/-- CRT Combination: reconstruct the unique global integer from the 3 residues.
    M = 71 * 59 * 47 = 196883
    M0 = 59 * 47 = 2773; M0_inv mod 71 = 18; term0 = 2773 * 18 = 49914
    M1 = 71 * 47 = 3337; M1_inv mod 59 = 34; term1 = 3337 * 34 = 113458
    M2 = 71 * 59 = 4189; M2_inv mod 47 = 8;  term2 = 4189 * 8  = 33512
-/
def crtCombine (s0 s1 s2 : Nat) : Nat :=
  (s0 * 49914 + s1 * 113458 + s2 * 33512) % 196883

end ERDFa
