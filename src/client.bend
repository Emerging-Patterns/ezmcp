# ezmcp/src/client: an MCP client's messages and how it reads replies, with
# no IO. src/io.bend POSTs them over ezhttp.
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import 0xa4d47e5f0f6044ac1a983d1b051fa47a/src/http.bend as Http
import ./rpc.bend as Rpc
import ./server.bend as Server
import ./sse.bend as Sse

# the params of initialize: the latest revision, no client capabilities,
# and the client's name and version (basic/lifecycle#initialization)
def init.params(name: String, version: String) -> Value.Json:
  Json.obj([("protocolVersion", Json.str(Server.latest())),
    ("capabilities", Json.obj([])),
    ("clientInfo", Json.obj([("name", Json.str(name)),
      ("version", Json.str(version))]))])

# the initialize request
def initialize(id: Value.Json, name: String, version: String) -> Value.Json:
  Rpc.request(id, "initialize", init.params(name, version))

# the notification a client sends once initialize succeeded
def initialized() -> Value.Json:  # noqa: L001 closed constant; notice_no_id holds for every notification
  Rpc.notice("notifications/initialized", Json.obj([]))

# a tools/list request
def tools(id: Value.Json) -> Value.Json:
  Rpc.request(id, "tools/list", Json.obj([]))

# a tools/call request
def call(id: Value.Json, name: String, args: Value.Json) -> Value.Json:
  Rpc.request(id, "tools/call",
    Json.obj([("name", Json.str(name)), ("arguments", args)]))

# the headers of every POST: a JSON body, both reply types accepted, and
# the negotiated revision once there is one (empty before initialize)
def headers(+version: String) -> List<&2, Http.Header>:
  Bool.pick(List<&2, Http.Header>, String.is_empty(version),
    [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"}],
    [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"},
      Http.H{"MCP-Protocol-Version", version}])

# whether a Content-Type is an event stream
def is.sse(+ctype: String) -> Bool:
  String.starts_with(String.to_lower(String.trim(ctype)), "text/event-stream")

# a reply body's JSON text: an event stream's last data, else the body
def body(sse: Bool, +text: String) -> String:
  match sse:
    case True{}:
      Sse.last(text)
    case False{}:
      text

def took.ok(+ctype: String, text: String, ok: Bool, +status: U32) -> Rpc.Reply:
  match ok:
    case True{}:
      Rpc.read(body(is.sse(ctype), text))
    case False{}:
      Rpc.Unread{"HTTP " ++ U32.show(status) ++ ": " ++ text}

# what an HTTP reply to a request says: a 200 is read as JSON or as an event
# stream by its Content-Type; any other status is unread
def took(+status: U32, ctype: String, text: String) -> Rpc.Reply:
  took.ok(ctype, text, U32.is_eq(status, 200), status)

# whether an HTTP reply to a notification accepted it: any 2xx
def accepted(+status: U32) -> Bool:  # noqa: L001 only src/io.bend calls it (MCP-TRUST-1)
  Bool.and(U32.is_ge(status, 200), U32.is_lt(status, 300))

# the revision an initialize result names, "" when it names none
def version(result: Value.Json) -> String:
  Maybe.default(&2, String, Json.as_str(Json.get(result, "protocolVersion")),
    "")
