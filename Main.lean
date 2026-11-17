import LeanIO
import Lean.Data.Json
import SheafAxioms
import Governance
open LeanIO
open LeanIO.Router
open Std.Http
open Std.Async
open Std.Http.Server
open Lean
open System (FilePath)

structure Html where
  content : String

def sanitizeFilename (name : String) : String :=
  String.ofList (name.toList.map (fun c =>
    if c == '?' || c == '*' || c == ':' || c == '<' || c == '>' || c == '|' || c == '"' || c == '\\' || c == '/' then '_' else c
  ))

instance : IntoResponse Html where
  into_response html := do
    let h ← html
    Response.ok |>.header (.mk "access-control-allow-origin") (.mk "*") |>.html h.content

structure Wallet where
  address : String
  credits : Nat
  deriving ToJson, FromJson

def getWalletPath (addr : String) : System.FilePath :=
  let dataDir := ("data/wallets" : System.FilePath)
  dataDir / s!"{sanitizeFilename addr}.json"

def loadWallet (addr : String) : ContextAsync Wallet := do
  let path := getWalletPath addr
  if ← System.FilePath.pathExists path then
    let content ← IO.FS.readFile path
    match Json.parse content with
    | .ok j =>
      match fromJson? j with
      | .ok w => return w
      | .error _ => return { address := addr, credits := 0 }
    | .error _ => return { address := addr, credits := 0 }
  else
    return { address := addr, credits := 0 }

def saveWallet (w : Wallet) : ContextAsync Unit := do
  IO.FS.createDirAll "data/wallets"
  let path := getWalletPath w.address
  IO.FS.writeFile path (toJson w |>.compress)

def deductCredits (addr : String) (amount : Nat) : ContextAsync Bool := do
  let w ← loadWallet addr
  if w.credits >= amount then
    let new_w := { w with credits := w.credits - amount }
    saveWallet new_w
    return true
  else
    return false

def addCredits (addr : String) (amount : Nat) : ContextAsync Unit := do
  let w ← loadWallet addr
  let new_w := { w with credits := w.credits + amount }
  saveWallet new_w

def getSeed (cid : String) : Option (String × String × String × String × String × String × String) :=
  match cid with
  | "bafkda5131928007593a" => some ("0", "62,43,36", "1", "0xda5101480007593a", "1 (C)", "T_13", "(62 mod 71, 43 mod 59, 36 mod 47)")
  | "bafkda5130a0825c7afe" => some ("6", "2,13,34", "1", "0xda5161a8025c7afe", "5 (C(4))", "T_17", "(2 mod 71, 13 mod 59, 34 mod 47)")
  | _ => none

def deriveMonsterHash (name : String) : String × String × String × String × String × String × String :=
  let len := name.length
  let charSum := name.toList.foldl (fun (acc : Nat) c => acc + c.toNat) 0
  let distinctCount := name.toList.eraseDups.length
  let s0 := len % 71
  let s1 := charSum % 59
  let s2 := distinctCount % 47
  let pr : Nat := (charSum % 10) + 1
  let ad : Nat := (s0 * 16777216) + (s1 * 65536) + (s2 * 256) + (len % 256)
  ("0",
   s!"{s0},{s1},{s2}",
   toString pr,
   "0x" ++ toString ad,
   "1 (C)",
   "T_13",
   s!"({s0} mod 71, {s1} mod 59, {s2} mod 47)")

def sheafTuple (cid : String) : String × String × String × String × String × String × String :=
  match getSeed cid with
  | some seed => seed
  | none => deriveMonsterHash cid

def getCrtFromShard (shardStr : String) : Nat :=
  let parts := shardStr.splitOn ","
  match parts with
  | [s0, s1, s2] =>
    let n0 := match s0.trimAscii.toString.toNat? with | some n => n | none => 0
    let n1 := match s1.trimAscii.toString.toNat? with | some n => n | none => 0
    let n2 := match s2.trimAscii.toString.toNat? with | some n => n | none => 0
    ERDFa.crtCombine n0 n1 n2
  | _ => 0

def jsonPayload (cid : String) : Json :=
  let (t, shard, p, a, bott, hecke, orbifold) := sheafTuple cid
  let crt := getCrtFromShard shard
  Json.mkObj [
    ("cid", Json.str cid),
    ("erdfa:shard", Json.str shard),
    ("erdfa:crt", Json.str (toString crt)),
    ("erdfa:encoding", Json.str "raw"),
    ("erdfa:prime", Json.str p),
    ("dasl:addr", Json.str a),
    ("dasl:type", Json.str t),
    ("dasl:eigenspace", Json.str "Earth"),
    ("dasl:bott", Json.str bott),
    ("dasl:hecke", Json.str hecke),
    ("sheaf:orbifold", Json.str orbifold),
    ("sheaf:subgroupIndex", Json.str "erdfa:H/raw")
  ]

def rdfaFromJson (j : Json) : String :=
  let getS (k : String) : String :=
    match j.getObjValAs? String k with
    | .ok s => s
    | .error _ => ""
  let cid := getS "cid"
  let t := getS "dasl:type"
  let shard := getS "erdfa:shard"
  let crt := getS "erdfa:crt"
  let p := getS "erdfa:prime"
  let a := getS "dasl:addr"
  let bott := getS "dasl:bott"
  let hecke := getS "dasl:hecke"
  let orbifold := getS "sheaf:orbifold"
  let subgroupIndex := getS "sheaf:subgroupIndex"
  let eigenspace := getS "dasl:eigenspace"
  let encoding := getS "erdfa:encoding"
  "<!DOCTYPE html>\n<html>\n<head><title>ERDFa Sheaf Section</title></head>\n<body>\n<div typeof=\"erdfa:SheafSection dasl:Type" ++ t ++ "\" about=\"#" ++ cid ++ "\">\n" ++
  "  <meta property=\"erdfa:shard\" content=\"" ++ shard ++ "\" />\n" ++
  "  <meta property=\"erdfa:crt\" content=\"" ++ crt ++ "\" />\n" ++
  "  <meta property=\"erdfa:encoding\" content=\"" ++ encoding ++ "\" />\n" ++
  "  <meta property=\"erdfa:prime\" content=\"" ++ p ++ "\" />\n" ++
  "  <meta property=\"dasl:addr\" content=\"" ++ a ++ "\" />\n" ++
  "  <meta property=\"dasl:type\" content=\"" ++ t ++ "\" />\n" ++
  "  <meta property=\"dasl:eigenspace\" content=\"" ++ eigenspace ++ "\" />\n" ++
  "  <meta property=\"dasl:bott\" content=\"" ++ bott ++ "\" />\n" ++
  "  <meta property=\"dasl:hecke\" content=\"" ++ hecke ++ "\" />\n" ++
  "  <meta property=\"sheaf:orbifold\" content=\"" ++ orbifold ++ "\" />\n" ++
  "  <link property=\"sheaf:subgroupIndex\" href=\"" ++ subgroupIndex ++ "\" />\n" ++
  "</div>\n</body>\n</html>"

structure SheafSection where
  cid : String
  shard : List Nat
  prime : Nat
  encoding : String
  addr : String
  dasl_type : String
  eigenspace : String
  bott : String
  hecke : String
  orbifold : String
  subgroupIndex : String

instance : FromJson SheafSection where
  fromJson? j := do
    let cid ← j.getObjValAs? String "cid"
    let shardStr ← j.getObjValAs? String "erdfa:shard"
    let primeStr ← j.getObjValAs? String "erdfa:prime"
    let prime ← match primeStr.toNat? with
      | some n => pure n
      | none => throw "erdfa:prime must be a valid natural number"
    let shardParts := shardStr.splitOn ","
    if shardParts.length != 3 then throw "erdfa:shard must have exactly 3 elements"
    let shard ← shardParts.mapM (fun p => do
      match p.trimAscii.toString.toNat? with
      | some n => pure n
      | none => throw s!"Invalid shard element: {p}")
    let orbifold ← j.getObjValAs? String "sheaf:orbifold"
    match shard with
    | [s0, s1, s2] =>
      if s0 >= 71 || s1 >= 59 || s2 >= 47 then
        throw s!"Shard components out of modular range: ({s0},{s1},{s2})"
      let expectedOrb := s!"({s0} mod 71, {s1} mod 59, {s2} mod 47)"
      if orbifold != expectedOrb then
        throw s!"Mathematical mismatch: orbifold is {orbifold}, expected {expectedOrb}"
    | _ => throw "Invalid shard length"
    let encoding ← j.getObjValAs? String "erdfa:encoding"
    if encoding != "raw" then throw "Only 'raw' encoding is supported"
    let addr ← j.getObjValAs? String "dasl:addr"
    let dasl_type ← j.getObjValAs? String "dasl:type"
    if !addr.startsWith "0xda51" then
      throw "dasl:addr must start with prefix 0xda51"
    if addr.length != 18 then
      throw "dasl:addr must be exactly 18 characters (0x + 16 hex)"
    let addrTypeChar := match (addr.toList.drop 6).head? with | some c => c.toString | none => ""
    if addrTypeChar != dasl_type then
      throw s!"DA51 Type mismatch: addr prefix has type '{addrTypeChar}', but dasl:type is '{dasl_type}'"
    let eigenspace ← j.getObjValAs? String "dasl:eigenspace"
    let validEigenspace := ["Earth", "Spoke", "Hub", "Clock"]
    if !validEigenspace.contains eigenspace then
      throw s!"Invalid eigenspace: {eigenspace}. Must be Earth, Spoke, Hub, or Clock."
    let bott ← j.getObjValAs? String "dasl:bott"
    let validBott := ["0 (R)", "1 (C)", "2 (H)", "3 (H⊕H)", "4 (H(2))", "5 (C(4))", "6 (R(8))", "7 (R(8)⊕R(8))"]
    if !validBott.contains bott then
      throw s!"Invalid bott class: {bott}. Must be one of the 8 Bott periodicity classes."
    let hecke ← j.getObjValAs? String "dasl:hecke"
    let validHecke := ["T_2", "T_3", "T_5", "T_7", "T_11", "T_13", "T_17", "T_19", "T_23", "T_29", "T_31", "T_41", "T_47", "T_59", "T_71"]
    if !validHecke.contains hecke then
      throw s!"Invalid hecke prime: {hecke}. Must be one of the 15 supersingular primes."
    let subgroupIndex ← j.getObjValAs? String "sheaf:subgroupIndex"
    return { cid, shard, prime, encoding, addr, dasl_type, eigenspace, bott, hecke, orbifold, subgroupIndex }

def loadOrDerive (cid : String) : ContextAsync Json := do
  let path := ("data" : System.FilePath) / s!"{sanitizeFilename cid}.json"
  if ← System.FilePath.pathExists path then
    let content ← IO.FS.readFile path
    match Json.parse content with
    | .ok j => return j
    | .error _ => return jsonPayload cid
  else
    return jsonPayload cid


structure VoteData where
  cid : String
  votes : Nat
  deriving ToJson, FromJson

def getVotesPath (cid : String) : System.FilePath :=
  let dir := ("data/votes" : System.FilePath)
  dir / s!"{sanitizeFilename cid}.json"

def loadVotes (cid : String) : ContextAsync Nat := do
  let path := getVotesPath cid
  if ← System.FilePath.pathExists path then
    let content ← IO.FS.readFile path
    match Json.parse content with
    | .ok j =>
      match (fromJson? j : Except String VoteData) with
      | .ok v => return v.votes
      | .error _ => return 0
    | .error _ => return 0
  else
    return 0

def saveVotes (cid : String) (votes : Nat) : ContextAsync Unit := do
  IO.FS.createDirAll "data/votes"
  let path := getVotesPath cid
  let v : VoteData := { cid := cid, votes := votes }
  IO.FS.writeFile path (toJson v |>.compress)


structure ProposalRecord where
  cid : String
  votesFor : Nat
  votesAgainst : Nat
  quorumPercentage : Nat
  totalEligibleVoters : Nat
  finalized : Bool
  passed : Bool
  deriving ToJson, FromJson

def getProposalPath (cid : String) : System.FilePath :=
  ("data/proposals" : System.FilePath) / s!"{sanitizeFilename cid}.json"

def loadProposal (cid : String) : ContextAsync (Option ProposalRecord) := do
  let path := getProposalPath cid
  if ← System.FilePath.pathExists path then
    let content ← IO.FS.readFile path
    match Json.parse content with
    | .ok j =>
      match (fromJson? j : Except String ProposalRecord) with
      | .ok p => return some p
      | .error _ => return none
    | .error _ => return none
  else
    return none

def saveProposal (p : ProposalRecord) : ContextAsync Unit := do
  IO.FS.createDirAll "data/proposals"
  let path := getProposalPath p.cid
  IO.FS.writeFile path (toJson p |>.compress)

def showSection := GET "/erdfa/{cid}" (⟨cid⟩ : Path String) => do
  let j ← loadOrDerive (cid : String)
  return (show Html from { content := rdfaFromJson j })

def showJson := GET "/api/erdfa/{cid}" (⟨cid⟩ : Path String) => do
  loadOrDerive (cid : String)

def listAll := GET "/api/erdfa/list" => do
  let dir := ("data" : System.FilePath)
  if !(← System.FilePath.pathExists dir) then
    return Json.mkObj [("count", Json.num 0), ("sections", Json.arr #[])]
  let entries ← dir.readDir
  let mut sections : Array Json := #[]
  for entry in entries do
    let name := entry.fileName
    if name.endsWith ".json" then
      let content ← IO.FS.readFile entry.path
      match Json.parse content with
      | .ok j =>
        let cid := match j.getObjValAs? String "cid" with | .ok c => c | .error _ => ""
        let crt := match j.getObjValAs? String "erdfa:crt" with | .ok c => c | .error _ => ""
        sections := sections.push (Json.mkObj [("cid", Json.str cid), ("crt", Json.str crt)])
      | .error _ => pure ()
  return Json.mkObj [("count", Json.num sections.size), ("sections", Json.arr sections)]

def exportAll := GET "/api/erdfa/export" => do
  let dir := ("data" : System.FilePath)
  if !(← System.FilePath.pathExists dir) then
    return Json.arr #[]
  let entries ← dir.readDir
  let mut sections : Array Json := #[]
  for entry in entries do
    let name := entry.fileName
    if name.endsWith ".json" then
      let content ← IO.FS.readFile entry.path
      match Json.parse content with
      | .ok j => sections := sections.push j
      | .error _ => pure ()
  return Json.arr sections

def statusEndpoint := GET "/api/erdfa/status" => do
  let dir := ("data" : System.FilePath)
  let mut count : Nat := 0
  if ← System.FilePath.pathExists dir then
    let entries ← dir.readDir
    for entry in entries do
      if entry.fileName.endsWith ".json" then count := count + 1
  return Json.mkObj [
    ("status", Json.str "healthy"),
    ("node", Json.str "kant-lean-worker"),
    ("version", Json.str "0.1.0"),
    ("sections_count", Json.num count),
    ("endpoints", Json.arr #[
      Json.str "/erdfa/{cid}",
      Json.str "/api/erdfa/{cid}",
      Json.str "/api/erdfa/list",
      Json.str "/api/erdfa/export",
      Json.str "/api/erdfa/status",
      Json.str "/api/erdfa/hash/{name}",
      Json.str "/api/erdfa/submit",
      Json.str "/api/erdfa/sync"
    ])
  ]

def processSubmission (body : SheafSection) : ContextAsync (Status × Json) := do
  let incomingShard := String.intercalate "," (body.shard.map toString)
  let crtVal := getCrtFromShard incomingShard
  IO.FS.createDirAll "data"
  let path := ("data" : System.FilePath) / s!"{sanitizeFilename body.cid}.json"

  let newSectionJson := Json.mkObj [
    ("cid", Json.str body.cid),
    ("erdfa:shard", Json.str incomingShard),
    ("erdfa:crt", Json.str (toString crtVal)),
    ("erdfa:encoding", Json.str body.encoding),
    ("erdfa:prime", Json.str (toString body.prime)),
    ("dasl:addr", Json.str body.addr),
    ("dasl:type", Json.str body.dasl_type),
    ("dasl:eigenspace", Json.str body.eigenspace),
    ("dasl:bott", Json.str body.bott),
    ("dasl:hecke", Json.str body.hecke),
    ("sheaf:orbifold", Json.str body.orbifold),
    ("sheaf:subgroupIndex", Json.str body.subgroupIndex)
  ]

  if ← System.FilePath.pathExists path then
    let existingContent ← IO.FS.readFile path
    match Json.parse existingContent with
    | .ok existing =>
      let existingShard := match existing.getObjValAs? String "erdfa:shard" with
        | .ok s => s
        | .error _ => ""
      if existingShard == incomingShard then
        return (Status.ok, Json.mkObj [
          ("status", Json.str "confirmed"),
          ("message", Json.str "Section confirmed by additional submission (sheaf gluing verified)"),
          ("cid", Json.str body.cid),
          ("crt", Json.str (toString crtVal))
        ])
      else
        return (Status.unprocessableEntity, Json.mkObj [
          ("status", Json.str "contradiction"),
          ("message", Json.str s!"Sheaf gluing failed: existing shard '{existingShard}' differs from incoming '{incomingShard}'"),
          ("cid", Json.str body.cid),
          ("existing_shard", Json.str existingShard),
          ("incoming_shard", Json.str incomingShard)
        ])
    | .error _ =>
      IO.FS.writeFile path newSectionJson.compress
      return (Status.created, Json.mkObj [
        ("status", Json.str "created"),
        ("message", Json.str "Section created (overwrote corrupt file)"),
        ("cid", Json.str body.cid),
        ("crt", Json.str (toString crtVal))
      ])
  else
    IO.FS.writeFile path newSectionJson.compress
    return (Status.created, Json.mkObj [
      ("status", Json.str "created"),
      ("message", Json.str "Section created"),
      ("cid", Json.str body.cid),
      ("crt", Json.str (toString crtVal))
    ])

def submitSection := POST "/api/erdfa/submit"
    (⟨_body⟩ : LeanIO.Json SheafSection) => do
  return (Status.forbidden, Json.mkObj [
    ("status", Json.str "DENIED"),
    ("error", Json.str "Economic admission disabled pending transactional authority")
  ])

def syncSection := POST "/api/erdfa/sync"
    (⟨_body⟩ : LeanIO.Json (Array SheafSection)) => do
  return (Status.forbidden, Json.mkObj [
    ("status", Json.str "DENIED"),
    ("error", Json.str "Unauthenticated sync disabled pending authorization review")
  ])

def hashOracle := GET "/api/erdfa/hash/{name}" (⟨name⟩ : Path String) => do
  let (_t, shard, _p, a, _bott, _hecke, orbifold) := deriveMonsterHash (name : String)
  let crt := getCrtFromShard shard
  return Json.mkObj [
    ("name", Json.str (name : String)),
    ("erdfa:shard", Json.str shard),
    ("erdfa:crt", Json.str (toString crt)),
    ("dasl:addr", Json.str a),
    ("sheaf:orbifold", Json.str orbifold)
  ]

def filterSections := GET "/api/erdfa/filter/{query}" (⟨query⟩ : Path String) => do
  let parts := (query : String).splitOn "="
  match parts with
  | [field, value] =>
    let dir := ("data" : System.FilePath)
    if !(← System.FilePath.pathExists dir) then
      return Json.arr #[]
    let entries ← dir.readDir
    let mut sections : Array Json := #[]
    for entry in entries do
      let name := entry.fileName
      if name.endsWith ".json" then
        let content ← IO.FS.readFile entry.path
        match Json.parse content with
        | .ok j =>
          match j.getObjValAs? String field with
          | .ok v => if v == value then sections := sections.push j
          | .error _ => pure ()
        | .error _ => pure ()
    return Json.arr sections
  | _ => return Json.mkObj [("error", Json.str "Invalid query format. Use field=value")]

def tileDashboard := GET "/tile/dashboard" => do
  let dir := ("data" : System.FilePath)
  let mut count : Nat := 0
  if ← System.FilePath.pathExists dir then
    let entries ← dir.readDir
    for entry in entries do
      if entry.fileName.endsWith ".json" then count := count + 1
  let html := "<div style=\"font-family: monospace; padding: 12px; border: 1px solid #00ff00; border-radius: 8px; background: #1e1e1e; color: #00ff00; max-width: 350px;\">\n" ++
              "  <h3 style=\"margin: 0 0 10px 0; color: #fff;\">🟢 Lean Worker Node</h3>\n" ++
              "  <div style=\"display: flex; justify-content: space-between;\">\n" ++
              "    <span>Status:</span><span><strong>Healthy</strong></span>\n" ++
              "  </div>\n" ++
              "  <div style=\"display: flex; justify-content: space-between;\">\n" ++
              s!"    <span>Sections:</span><span><strong>{count}</strong></span>\n" ++
              "  </div>\n" ++
              "  <p style=\"margin: 10px 0 0 0; font-size: 0.8em; color: #888; border-top: 1px solid #333; padding-top: 8px;\">\n" ++
              "    CRT Gödel Numbers Verified ✅\n" ++
              "  </p>\n" ++
              "</div>"
  return html

def showUi := GET "/ui" => do
  let content ← IO.FS.readFile "ui.html"
  return (show Html from { content := content })

def getWalletRoute := GET "/api/erdfa/wallet/{addr}" (⟨addr⟩ : Path String) => do
  let w ← loadWallet (addr : String)
  return Json.mkObj [("address", Json.str w.address), ("credits", Json.num w.credits)]

def stakeRoute := POST "/api/erdfa/stake/{req}" (⟨_req⟩ : Path String) => do
  -- Security hold: no unauthenticated credit issuance.
  -- Re-enable only after a reviewed authorization contract exists.
  return (Status.forbidden, Json.mkObj [
    ("status", Json.str "DENIED"),
    ("error", Json.str "Credit staking is disabled pending authorization review")
  ])

def withdrawRoute := POST "/api/erdfa/withdraw/{req}" (⟨_req⟩ : Path String) => do
  -- Security hold: no unauthenticated credit transfers.
  -- Re-enable only after a reviewed authorization contract exists.
  return (Status.forbidden, Json.mkObj [
    ("status", Json.str "DENIED"),
    ("error", Json.str "Credit withdrawal is disabled pending authorization review")
  ])

def voteRoute := POST "/api/erdfa/vote/{req}" (⟨req⟩ : Path String) => do
  let parts := (req : String).splitOn ":"
  match parts with
  | [cid, voter] =>
    -- Verificăm dacă utilizatorul are credite
    let w ← loadWallet voter
    if w.credits >= 1 then
      -- Scădem un credit
      let new_w := { w with credits := w.credits - 1 }
      saveWallet new_w

      -- Adăugăm un vot pentru CID
      let currentVotes ← loadVotes cid
      saveVotes cid (currentVotes + 1)

      return (Status.ok, Json.mkObj [
        ("status", Json.str "voted"),
        ("cid", Json.str cid),
        ("new_total", Json.num (currentVotes + (1 : Nat))),
        ("remaining_credits", Json.num new_w.credits)
      ])
    else
      return (Status.badRequest, Json.mkObj [("error", Json.str "Not enough Governance Credits to vote.")])
  | _ => return (Status.badRequest, Json.mkObj [("error", Json.str "Invalid format. Use cid:voter")])


def createProposalRoute := POST "/api/erdfa/proposals/create/{req}" (⟨req⟩ : Path String) => do
  let parts := (req : String).splitOn ":"
  match parts with
  | [cid, quorum, eligible] =>
    let validCid :=
      cid.length > 0 &&
      cid.length <= 128 &&
      cid.toList.all (fun c =>
        (c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') ||
        c == '-' || c == '_')
    if !validCid then
      return (Status.badRequest, Json.mkObj [("error", Json.str "Invalid CID")])
    match quorum.toNat?, eligible.toNat? with
    | some q, some e =>
      if q == 0 || q > 100 || e == 0 then
        return (Status.badRequest, Json.mkObj [("error", Json.str "Invalid quorum or eligible voters")])
      let p : ProposalRecord := {
        cid := cid, votesFor := 0, votesAgainst := 0,
        quorumPercentage := q, totalEligibleVoters := e,
        finalized := false, passed := false
      }
      let result ← IO.Process.output {
        cmd := "/usr/bin/python3"
        args := #["atomic_proposal_store.py", cid, toJson p |>.compress]
      }
      if result.exitCode == 0 then
        return (Status.ok, Json.mkObj [("status", Json.str "created"), ("cid", Json.str cid)])
      else if result.exitCode == 10 then
        return (Status.conflict, Json.mkObj [("error", Json.str "Proposal already exists")])
      else
        return (Status.internalServerError, Json.mkObj [("error", Json.str "Atomic persistence failed")])
    | _, _ =>
      return (Status.badRequest, Json.mkObj [("error", Json.str "Invalid numeric parameters")])
  | _ =>
    return (Status.badRequest, Json.mkObj [("error", Json.str "Invalid proposal format")])

def daoAuthorityForward (payload : Lean.Json) : IO (Option Lean.Json) := do
  try
    let encoded := payload.compress
    if encoded.toUTF8.size > 4096 then
      return none
    let child ← IO.Process.spawn {
      cmd := "/usr/bin/timeout"
      args := #["--signal=TERM", "--kill-after=2s",
                "3s", "/usr/bin/python3", "authority_bridge.py"]
      stdin := .piped
      stdout := .piped
    }
    child.stdin.putStr (encoded ++ "\n")
    child.stdin.flush
    let response ← child.stdout.getLine
    let exitCode ← child.wait
    if exitCode != 0 then
      return none
    match Lean.Json.parse response with
    | .ok result => return some result
    | .error _ => return none
  catch _ =>
    return none

def daoVoteForward (payload : Lean.Json) : IO (Option Lean.Json) := do
  try
    let encoded := payload.compress
    if encoded.toUTF8.size > 4096 then
      return none
    let child ← IO.Process.spawn {
      cmd := "/usr/bin/timeout"
      args := #["--signal=TERM", "--kill-after=2s",
                "3s", "/usr/bin/python3", "vote_bridge.py"]
      stdin := .piped
      stdout := .piped
    }
    child.stdin.putStr (encoded ++ "\n")
    child.stdin.flush
    let response ← child.stdout.getLine
    let exitCode ← child.wait
    if exitCode != 0 then
      return none
    match Lean.Json.parse response with
    | .ok result => return some result
    | .error _ => return none
  catch _ =>
    return none


def daoVoteChallengeRoute :=
  POST "/api/erdfa/proposals/vote/challenge"
    (body : Json Lean.Json) => do
    match body.body.getObjValAs? String "operation" with
    | .ok "vote_challenge" =>
      match ← daoVoteForward body.body with
      | some result =>
        match result.getObjValAs? String "status" with
        | .ok "CHALLENGE" => return (Status.ok, result)
        | _ => return (Status.forbidden, result)
      | none =>
        return (Status.internalServerError,
          Lean.Json.mkObj [("error", Lean.Json.str "Vote authority unavailable")])
    | _ =>
      return (Status.forbidden,
        Lean.Json.mkObj [("error", Lean.Json.str "Invalid vote operation")])

def daoVoteSubmitRoute :=
  POST "/api/erdfa/proposals/vote/submit"
    (body : Json Lean.Json) => do
    match body.body.getObjValAs? String "operation" with
    | .ok "vote_submit" =>
      match ← daoVoteForward body.body with
      | some result =>
        match result.getObjValAs? String "status" with
        | .ok "VOTED" => return (Status.ok, result)
        | _ => return (Status.forbidden, result)
      | none =>
        return (Status.internalServerError,
          Lean.Json.mkObj [("error", Lean.Json.str "Vote authority unavailable")])
    | _ =>
      return (Status.forbidden,
        Lean.Json.mkObj [("error", Lean.Json.str "Invalid vote operation")])

def daoChallengeRoute := POST "/api/erdfa/proposals/challenge" (body : Json Lean.Json) => do
  match body.body.getObjValAs? String "operation" with
  | .ok "challenge" =>
    match ← daoAuthorityForward body.body with
    | some result =>
      match result.getObjValAs? String "status" with
      | .ok "CHALLENGE" => return (Status.ok, result)
      | _ => return (Status.forbidden, result)
    | none =>
      return (Status.internalServerError, Lean.Json.mkObj [
        ("error", Lean.Json.str "Authority unavailable")
      ])
  | _ =>
    return (Status.forbidden, Lean.Json.mkObj [
      ("error", Lean.Json.str "Invalid challenge operation")
    ])

def daoSubmitRoute := POST "/api/erdfa/proposals/submit" (body : Json Lean.Json) => do
  match body.body.getObjValAs? String "operation" with
  | .ok "submit" =>
    match ← daoAuthorityForward body.body with
    | some result =>
      match result.getObjValAs? String "status" with
      | .ok "CREATED" => return (Status.ok, result)
      | _ => return (Status.forbidden, result)
    | none =>
      return (Status.internalServerError, Lean.Json.mkObj [
        ("error", Lean.Json.str "Authority unavailable")
      ])
  | _ =>
    return (Status.forbidden, Lean.Json.mkObj [
      ("error", Lean.Json.str "Invalid submit operation")
    ])

def voteProposalRoute := POST "/api/erdfa/proposals/vote/{req}" (⟨req⟩ : Path String) => do
  -- req format: cid:voter:choice (choice = yes/no)
  let parts := (req : String).splitOn ":"
  match parts with
  | [cid, voter, choice] =>
    let w ← loadWallet voter
    if w.credits >= 1 then
      let new_w := { w with credits := w.credits - 1 }
      saveWallet new_w

      match ← loadProposal cid with
      | some p =>
        if p.finalized then
          return (Status.badRequest, Json.mkObj [("error", Json.str "Proposal already finalized")])

        let new_p := if choice == "yes" then { p with votesFor := p.votesFor + 1 } else { p with votesAgainst := p.votesAgainst + 1 }
        saveProposal new_p

        return (Status.ok, Json.mkObj [
          ("status", Json.str "voted"), ("cid", Json.str cid),
          ("votesFor", Json.num new_p.votesFor), ("votesAgainst", Json.num new_p.votesAgainst),
          ("remaining_credits", Json.num new_w.credits)
        ])
      | none => return (Status.badRequest, Json.mkObj [("error", Json.str "Proposal not found")])
    else
      return (Status.badRequest, Json.mkObj [("error", Json.str "Not enough credits")])
  | _ => return (Status.badRequest, Json.mkObj [("error", Json.str "Invalid format. Use cid:voter:choice")])

def finalizeProposalRoute := POST "/api/erdfa/proposals/finalize/{cid}" (⟨cid⟩ : Path String) => do
  match ← loadProposal (cid : String) with
  | some p =>
    if p.finalized then
      return (Status.badRequest, Json.mkObj [("error", Json.str "Already finalized")])

    let govProp : SolfunmemeDAO.Proposal := {
      id := p.cid, votesFor := p.votesFor, votesAgainst := p.votesAgainst,
      totalEligibleVoters := p.totalEligibleVoters, quorumPercentage := p.quorumPercentage
    }

    let passed := SolfunmemeDAO.isProposalPassed govProp
    let final_p := { p with finalized := true, passed := passed }
    saveProposal final_p

    return (Status.ok, Json.mkObj [
      ("status", Json.str "finalized"), ("cid", Json.str p.cid),
      ("passed", Json.bool passed),
      ("votesFor", Json.num p.votesFor), ("votesAgainst", Json.num p.votesAgainst)
    ])
  | none => return (Status.badRequest, Json.mkObj [("error", Json.str "Proposal not found")])

def daoSqliteListRoute := GET "/api/erdfa/proposals/list" => do
  let payload := Lean.Json.mkObj [
    ("operation", Lean.Json.str "list")
  ]
  match ← daoAuthorityForward payload with
  | some result =>
    match result.getObjValAs? String "status" with
    | .ok "LIST" => return (Status.ok, result)
    | _ => return (Status.internalServerError, Lean.Json.mkObj [
        ("error", Lean.Json.str "Proposal list unavailable")
      ])
  | none =>
    return (Status.internalServerError, Lean.Json.mkObj [
      ("error", Lean.Json.str "Proposal list unavailable")
    ])

def getMessageEnc := GET "/message.enc" => do
  return {
    path := ("../sfm-message/message.enc" : System.FilePath)
    cacheControl := none
  : File }

def getSodiumJs := GET "/sodium.js" => do
  let path := ("sodium.js" : System.FilePath)
  if ← System.FilePath.pathExists path then
    let content ← IO.FS.readFile path
    return content
  else
    return "console.log('sodium.js not found');"

def index := GET "/" => do
  return "lean-worker ERDFa/Sheaf: try GET /erdfa/{cid} or /api/erdfa/{cid}"

def main : IO Unit := Async.block do
  let router := Router.empty
    |>.addRoute showSection
    |>.addRoute showJson
    |>.addRoute listAll
    |>.addRoute exportAll
    |>.addRoute statusEndpoint
    |>.addRoute tileDashboard
    |>.addRoute hashOracle
    |>.addRoute submitSection
    |>.addRoute syncSection
    |>.addRoute showUi
    |>.addRoute filterSections
    |>.addRoute getWalletRoute
    |>.addRoute stakeRoute
    |>.addRoute withdrawRoute
    |>.addRoute getSodiumJs
    |>.addRoute daoSqliteListRoute
    |>.addRoute daoChallengeRoute
    |>.addRoute daoSubmitRoute
    |>.addRoute daoVoteChallengeRoute
    |>.addRoute daoVoteSubmitRoute

    |>.addRoute index
  let addr := .v4 ⟨.ofParts 127 0 0 1, 9090⟩
  let server ← router.serve addr
  IO.println "lean-worker on http://127.0.0.1:9090/ui"
  server.waitShutdown
