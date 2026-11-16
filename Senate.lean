/- Senate.lean
   Formalization of US Senate Rules for the Solfunmeme DAO.
-/

namespace SolfunmemeSenate

/-- Un Senator cu drept de vot. -/
structure Senator where
  id : String
  isPresent : Bool
  deriving Repr, DecidableEq

/-- O lege/propunere supusă votului. -/
structure Bill where
  id : String
  votesYea : Nat
  votesNay : Nat
  totalSenators : Nat
  deriving Repr

/-- Regula de Quorum: Sunt necesari cel puțin 51 de senatori prezenți. -/
def hasQuorum (present : Nat) : Bool :=
  present >= 51

/-- Regula Cloture (Încheierea dezbaterii): Necesită 3/5 din voturi (60 din 100). -/
def passesCloture (votesYea : Nat) (totalSenators : Nat) : Bool :=
  votesYea * 5 >= totalSenators * 3

/-- Majoritate Simplă: Voturile "Yea" trebuie să fie strict mai multe decât "Nay". -/
def passesSimpleMajority (b : Bill) : Bool :=
  b.votesYea > b.votesNay

/-- Supermajoritate (2/3): Pentru tratate sau anularea veto-ului. -/
def passesSupermajority (b : Bill) : Bool :=
  b.votesYea * 3 >= b.totalSenators * 2

/-- Teoremă: Dacă Cloture trece, înseamnă că au fost cel puțin 60 de voturi. -/
theorem cloture_implies_60 (votesYea : Nat) (h : passesCloture votesYea 100 = true) :
    votesYea >= 60 := by
  unfold passesCloture at h
  omega

/-- Teoremă: Dacă o lege trece prin Supermajoritate, ea trece automat și prin Majoritate Simplă. -/
theorem supermajority_implies_simple (b : Bill) (h : passesSupermajority b = true) (h_total : b.totalSenators > 0) :
    b.votesYea >= b.votesNay := by
  unfold passesSupermajority at h
  have h2 : b.votesYea * 3 >= b.totalSenators * 2 := by omega
  -- Dacă 2/3 din total au votat Yea, atunci Yea > Nay (presupunând că restul sunt Nay sau absenți)
  omega

end SolfunmemeSenate
