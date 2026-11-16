/- NewJerseyLLC.lean
   Formalization of the Operating Agreement for the Solfunmeme LLC (NJ).
   Ensures mathematical safety for fundraising and hardware acquisition.
-/

namespace SolfunmemeLLC

/-- Structura unui Membru (Investitor). -/
structure Member where
  id : String
  capitalContributed : Nat -- Contribuția în USD/Tokeni
  votingPower : Nat         -- Puterea de vot (credite)
  deriving Repr

/-- Trezoreria Companiei. -/
structure Treasury where
  totalCapital : Nat
  hardwareAcquired : Nat -- Valoarea hardware-ului deținut (GPU, Server)
  deriving Repr

/-- O rezoluție de achiziție a hardware-ului (ex: cumpărare GPU-uri pentru Data Center). -/
structure HardwareProposal where
  id : String
  cost : Nat
  votesFor : Nat
  votesAgainst : Nat
  deriving Repr

/-- Bylaw-ul de Siguranță Financiară: Trezoreria nu poate cheltui mai mult decât are. -/
def canAfford (t : Treasury) (p : HardwareProposal) : Bool :=
  t.totalCapital >= p.cost

/-- Bylaw-ul de Guvernanță: Achiziția necesită majoritate simplă. -/
def hasMajority (p : HardwareProposal) : Bool :=
  p.votesFor > p.votesAgainst

/-- Regula de Bază a LLC-ului: O achiziție este aprobată doar dacă are majoritate ȘI compania are fondurile necesare. -/
def isHardwarePurchaseApproved (t : Treasury) (p : HardwareProposal) : Bool :=
  canAfford t p && hasMajority p

/-- Teorema de Protecție a Investitorilor:
    Dacă o achiziție este aprobată matematic, atunci costul ei este strict mai mic sau egal cu capitalul total.
    (Adică, sistemul nu permite niciodată datorii neacoperite sau fonduri deturnate). -/
theorem approved_implies_solvent (t : Treasury) (p : HardwareProposal)
    (h : isHardwarePurchaseApproved t p = true) : p.cost <= t.totalCapital := by
  unfold isHardwarePurchaseApproved at h
  simp at h
  have h_afford := h.left
  unfold canAfford at h_afford
  exact h_afford

/-- Teorema de Aplicare a Fondurilor (Allocation):
    O funcție pură care execută achiziția. Dacă este aprobată, capitalul scade, iar hardware-ul crește. -/
def executePurchase (t : Treasury) (p : HardwareProposal) (h : isHardwarePurchaseApproved t p = true) : Treasury :=
  { totalCapital := t.totalCapital - p.cost, hardwareAcquired := t.hardwareAcquired + p.cost }

/-- Teorema de Conservare a Valorii:
    Valoarea totală (Capital + Hardware) rămâne constantă în urma achiziției. -/
theorem value_preservation (t : Treasury) (p : HardwareProposal) (h : isHardwarePurchaseApproved t p = true) :
    (executePurchase t p h).totalCapital + (executePurchase t p h).hardwareAcquired = t.totalCapital + t.hardwareAcquired := by
  unfold executePurchase
  simp
  have h_solvent := approved_implies_solvent t p h
  omega

end SolfunmemeLLC
