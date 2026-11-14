/- SheafAxioms.lean
   Formal skeleton for ERDFa sheaf gluing.

   The sheaf axiom: two sections s, t on overlapping domains, compatible
   on their intersection, glue to a unique section on the union.

   This is the mathematical foundation of "agreement" in the
   content-addressed knowledge graph: locally verified sections
   compose uniquely into global sections.
-/

namespace ERDFa

/-- A numeric section: a value at each modular coordinate. -/
def Section := Nat → Nat

/-- Sheaf gluing uniqueness.

    If u and v both extend s on domL and t on domR to the union,
    then u and v agree everywhere on the union.

    This is the "local determination" property:
    once the pieces are pinned, the global section is unique. -/
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

end ERDFa
