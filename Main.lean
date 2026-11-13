import LeanIO
open LeanIO
open LeanIO.Router
open Std.Http
open Std.Async
open Std.Http.Server

structure Html where
  content : String

instance : IntoResponse Html where
  into_response html := do
    let h ← html
    Response.ok |>.header (.mk "content-type") (.mk "text/html; charset=utf-8") |>.header (.mk "access-control-allow-origin") (.mk "*") |>.bytes h.content.toUTF8

structure Json where
  content : String

instance : IntoResponse Json where
  into_response json := do
    let j ← json
    Response.ok |>.header (.mk "content-type") (.mk "application/json") |>.header (.mk "access-control-allow-origin") (.mk "*") |>.bytes j.content.toUTF8

def rdfaPayload (cid : String) : String :=
  let h := hash cid
  let p := (h % 10) + 1
  let a := h * 16
  "<div typeof=\"erdfa:SheafSection dasl:Type0\" about=\"#" ++ cid ++ "\">\n" ++
  "  <meta property=\"erdfa:shard\" content=\"62,43,36\" />\n" ++
  "  <meta property=\"erdfa:encoding\" content=\"raw\" />\n" ++
  "  <meta property=\"erdfa:prime\" content=\"" ++ toString p ++ "\" />\n" ++
  "  <meta property=\"dasl:addr\" content=\"0x" ++ toString a ++ "\" />\n" ++
  "  <meta property=\"dasl:type\" content=\"0\" />\n" ++
  "  <meta property=\"dasl:eigenspace\" content=\"Earth\" />\n" ++
  "  <meta property=\"dasl:bott\" content=\"1 (C)\" />\n" ++
  "  <meta property=\"dasl:hecke\" content=\"T_13\" />\n" ++
  "  <meta property=\"sheaf:orbifold\" content=\"(62 mod 71, 43 mod 59, 36 mod 47)\" />\n" ++
  "  <link property=\"sheaf:subgroupIndex\" href=\"erdfa:H/raw\" />\n" ++
  "</div>"

def jsonPayload (cid : String) : String :=
  let h := hash cid
  let p := (h % 10) + 1
  let a := h * 16
  "{\n" ++
  "  \"cid\": \"" ++ cid ++ "\",\n" ++
  "  \"erdfa:shard\": \"62,43,36\",\n" ++
  "  \"erdfa:encoding\": \"raw\",\n" ++
  "  \"erdfa:prime\": \"" ++ toString p ++ "\",\n" ++
  "  \"dasl:addr\": \"0x" ++ toString a ++ "\",\n" ++
  "  \"dasl:type\": \"0\",\n" ++
  "  \"dasl:eigenspace\": \"Earth\",\n" ++
  "  \"dasl:bott\": \"1 (C)\",\n" ++
  "  \"dasl:hecke\": \"T_13\",\n" ++
  "  \"sheaf:orbifold\": \"(62 mod 71, 43 mod 59, 36 mod 47)\",\n" ++
  "  \"sheaf:subgroupIndex\": \"erdfa:H/raw\"\n" ++
  "}"

def showSection := GET "/erdfa/{cid}" (⟨cid⟩ : Path String) => do
  return (show Html from { content := rdfaPayload (cid : String) })

def showJson := GET "/api/erdfa/{cid}" (⟨cid⟩ : Path String) => do
  return (show Json from { content := jsonPayload (cid : String) })

def index := GET "/" => do
  return "lean-worker ERDFa/Sheaf: try GET /erdfa/{cid} or /api/erdfa/{cid}"

def main : IO Unit := Async.block do
  let router := Router.empty |>.addRoute showSection |>.addRoute showJson |>.addRoute index
  let addr := .v4 ⟨.ofParts 127 0 0 1, 8080⟩
  let server ← router.serve addr
  IO.println "lean-worker on http://127.0.0.1:8080"
  server.waitShutdown
