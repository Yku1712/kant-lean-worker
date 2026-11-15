import LeanIO
import Lean.Data.Json
import SheafAxioms
open LeanIO
open LeanIO.Router
open Std.Http
open Std.Async
open Std.Http.Server
open Lean

structure Html where
  content : String

instance : IntoResponse Html where
  into_response html := do
    let h ← html
    Response.ok |>.header (.mk "content-type") (.mk "text/html; charset=utf-8") |>.header (.mk "access-control-allow-origin") (.mk "*") |>.text h.content

structure CorsGetResponse where
  dummy : Unit

instance : IntoResponse CorsGetResponse where
  into_response _ := do
    Response.ok
      |>.header (.mk "access-control-allow-origin") (.mk "*")
      |>.header (.mk "access-control-allow-methods") (.mk "GET, OPTIONS")
      |>.header (.mk "access-control-allow-headers") (.mk "Content-Type")
      |>.text ""

structure CorsPostResponse where
  dummy : Unit

instance : IntoResponse CorsPostResponse where
  into_response _ := do
    Response.ok
      |>.header (.mk "access-control-allow-origin") (.mk "*")
      |>.header (.mk "access-control-allow-methods") (.mk "POST, OPTIONS")
      |>.header (.mk "access-control-allow-headers") (.mk "Content-Type")
      |>.text ""

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

def rdfaPayload (cid : String) : String :=
  let (t, shard, p, a, bott, hecke, orbifold) := sheafTuple cid
  let crt := getCrtFromShard shard
  "<!DOCTYPE html>\n<html>\n<head><title>ERDFa Sheaf Section</title></head>\n<body>\n<div typeof=\"erdfa:SheafSection dasl:Type" ++ t ++ "\" about=\"#" ++ cid ++ "\">\n" ++
  "  <meta property=\"erdfa:shard\" content=\"" ++ shard ++ "\" />\n" ++
  "  <meta property=\"erdfa:crt\" content=\"" ++ toString crt ++ "\" />\n" ++
  "  <meta property=\"erdfa:encoding\" content=\"raw\" />\n" ++
  "  <meta property=\"erdfa:prime\" content=\"" ++ p ++ "\" />\n" ++
  "  <meta property=\"dasl:addr\" content=\"" ++ a ++ "\" />\n" ++
  "  <meta property=\"dasl:type\" content=\"" ++ t ++ "\" />\n" ++
  "  <meta property=\"dasl:eigenspace\" content=\"Earth\" />\n" ++
  "  <meta property=\"dasl:bott\" content=\"" ++ bott ++ "\" />\n" ++
  "  <meta property=\"dasl:hecke\" content=\"" ++ hecke ++ "\" />\n" ++
  "  <meta property=\"sheaf:orbifold\" content=\"" ++ orbifold ++ "\" />\n" ++
  "  <link property=\"sheaf:subgroupIndex\" href=\"erdfa:H/raw\" />\n" ++
  "</div>\n</body>\n</html>"

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
    let addr ← j.getObjValAs? String "dasl:addr"
    let dasl_type ← j.getObjValAs? String "dasl:type"
    let eigenspace ← j.getObjValAs? String "dasl:eigenspace"
    let bott ← j.getObjValAs? String "dasl:bott"
    let hecke ← j.getObjValAs? String "dasl:hecke"
    let subgroupIndex ← j.getObjValAs? String "sheaf:subgroupIndex"
    return { cid, shard, prime, encoding, addr, dasl_type, eigenspace, bott, hecke, orbifold, subgroupIndex }

def showSection := GET "/erdfa/{cid}" (⟨cid⟩ : Path String) => do
  return (show Html from { content := rdfaPayload (cid : String) })

def showJson := GET "/api/erdfa/{cid}" (⟨cid⟩ : Path String) => do
  return (jsonPayload (cid : String))

def submitSection := POST "/api/erdfa/submit" (⟨body⟩ : LeanIO.Json SheafSection) => do
  let crtVal := getCrtFromShard (String.intercalate "," (body.shard.map toString))
  return Json.mkObj [
    ("status", Json.str "ok"),
    ("message", Json.str "SheafSection validated mathematically"),
    ("cid", Json.str body.cid),
    ("crt", Json.str (toString crtVal))
  ]

def corsGet := OPTIONS "/api/erdfa/{cid}" (⟨_cid⟩ : Path String) => do
  return (show CorsGetResponse from { dummy := () })

def corsSubmit := OPTIONS "/api/erdfa/submit" => do
  return (show CorsPostResponse from { dummy := () })

def index := GET "/" => do
  return "lean-worker ERDFa/Sheaf: try GET /erdfa/{cid} or /api/erdfa/{cid}"

def main : IO Unit := Async.block do
  let router := Router.empty 
    |>.addRoute showSection 
    |>.addRoute showJson 
    |>.addRoute submitSection 
    |>.addRoute corsGet
    |>.addRoute corsSubmit
    |>.addRoute index
  let addr := .v4 ⟨.ofParts 0 0 0 0, 8080⟩
  let server ← router.serve addr
  IO.println "lean-worker on http://127.0.0.1:8080"
  server.waitShutdown
