# ezmcp/src/web: the streamable HTTP transport's decisions, with no IO
# (basic/transports#streamable-http). One HTTP request in, a reply out, or a
# tool call for src/io.bend to run before it replies with `ran`. Every POST
# is answered with one JSON body or 202; there is no SSE stream and no
# session.
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import 0xd3f9c1f02240edb63fd4a109ceb8fa74/src/http.bend as Http
import ./rpc.bend as Rpc
import ./server.bend as Server

# what the transport does with one HTTP request
type Web is Data:
  Now{status: U32, headers: List<&2, Http.Header>, body: String}
  Later{id: Value.Json, name: String, args: Value.Json}

# the header a JSON body carries
def json() -> List<&2, Http.Header>:
  [Http.H{"Content-Type", "application/json"}]

# a reply with a JSON body
def json.reply(status: U32, val: Value.Json) -> Web:
  Now{status, json(), Json.print(val)}

# a server's act as an HTTP reply: a request's reply is 200 with its JSON, a
# notification or a response is 202 with no body, a message the server
# cannot accept is 400 with its error
def act(lead: Server.Act) -> Web:
  match lead:
    case Server.Quiet{}:
      Now{202, [], ""}
    case Server.Send{reply}:
      json.reply(200, reply)
    case Server.Fault{reply}:
      json.reply(400, reply)
    case Server.Run{id, name, args}:
      Later{id, name, args}

# the reply to a tool call, once it ran
def ran(id: Value.Json, result: Value.Json) -> Web:
  json.reply(200, Server.ran(id, result))

# a request-target's path: everything before `?`
def path.of(target: String) -> String:
  Http.first(String.split(target, '?'))

# true at a hit, else the rest of the search
def origin.or(hit: Bool, rest: Unit -> Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      rest(Unit{})

# whether the server lists an Origin
def origin.listed(origins: List<&2, String>, +origin: String) -> Bool:
  match origins:
    case []:
      False{}
    case listed <> rest:
      origin.or(String.eq(listed, origin), _u => origin.listed(rest, origin))

# a port's digits after a colon
def loopback.colon(tail: String, colon: Bool) -> Bool:
  match colon:
    case True{}:
      Rpc.digits(tail)
    case False{}:
      False{}

# after the host: nothing, or a colon and a port's digits
def loopback.port(rest: String) -> Bool:
  match rest:
    case SNil{}:
      True{}
    case SCon{head, tail}:
      loopback.colon(tail, Char.is_eq(head, ':'))

# a host of n chars that is a loopback name, then a port
def loopback.at(+after: String, num: Nat, hit: Bool) -> Bool:
  match hit:
    case True{}:
      loopback.port(String.drop(after, num))
    case False{}:
      False{}

# whether what follows the scheme is a loopback host and an optional port
def loopback.host(+after: String) -> Bool:
  origin.or(loopback.at(after, 9n, String.starts_with(after, "localhost")),
    _u => origin.or(loopback.at(after, 9n,
      String.starts_with(after, "127.0.0.1")),
      _v => loopback.at(after, 5n, String.starts_with(after, "[::1]"))))

# a scheme of n chars, then a loopback host
def loopback.scheme(+origin: String, num: Nat, hit: Bool) -> Bool:
  match hit:
    case True{}:
      loopback.host(String.drop(origin, num))
    case False{}:
      False{}

# whether an Origin is a page on this machine: http or https, host
# localhost, 127.0.0.1 or [::1], and an optional port
def loopback(+origin: String) -> Bool:
  origin.or(loopback.scheme(origin, 7n, String.starts_with(origin, "http://")),
    _u => loopback.scheme(origin, 8n, String.starts_with(origin, "https://")))

# whether an Origin is allowed: an absent one (a client that is not a
# browser), a page on this machine, or one the server lists
def origin.ok(origins: List<&2, String>, +origin: String) -> Bool:
  origin.or(String.is_empty(origin),
    _u => origin.or(loopback(origin), _v => origin.listed(origins, origin)))

# whether an MCP-Protocol-Version header is acceptable: absent, or a
# revision ezmcp speaks
def version.ok(+val: String) -> Bool:
  Bool.or(String.is_empty(val), Server.supported(val))

# a plain-text reply
def text(status: U32, body: String) -> Web:
  Now{status, [Http.H{"Content-Type", "text/plain"}], body}

# a POST: refused for an unsupported revision, else the server's step
def post(srv: Server.Server, body: String, version: Bool) -> Web:
  match version:
    case False{}:
      text(400, "Bad Request: unsupported MCP-Protocol-Version")
    case True{}:
      act(Server.step(srv, body))

# any method but POST is 405
def method(
  srv: Server.Server,
  body: String,
  version: Bool,
  is_post: Bool
) -> Web:
  match is_post:
    case False{}:
      Now{405, [Http.H{"Allow", "POST"}], ""}
    case True{}:
      post(srv, body, version)

# a request whose Origin is not allowed is 403
def origin(
  srv: Server.Server,
  body: String,
  version: Bool,
  is_post: Bool,
  allowed: Bool
) -> Web:
  match allowed:
    case False{}:
      text(403, "Forbidden: Origin not allowed")
    case True{}:
      method(srv, body, version, is_post)

# the decision over a request's parts: the path first, then the Origin, then
# the method, then the protocol version, then the body
def route(
  srv: Server.Server,
  here: Bool,
  allowed: Bool,
  is_post: Bool,
  version: Bool,
  body: String
) -> Web:
  match here:
    case False{}:
      text(404, "Not Found")
    case True{}:
      origin(srv, body, version, is_post, allowed)

# what the transport does with one HTTP request to an endpoint at `path`,
# which allows the browser origins listed
def decide(
  srv: Server.Server,
  path: String,
  origins: List<&2, String>,
  req: Http.Request
) -> Web:
  match req:
    case Http.Bad{why}:
      text(400, why)
    case Http.Request{+m, +target, +headers, body}:
      route(srv, String.eq(path.of(target), path),
        origin.ok(origins, Http.headers.find(headers, "Origin")),
        String.eq(m, "POST"),
        version.ok(Http.headers.find(headers, "MCP-Protocol-Version")), body)

# a Web reply as ezhttp's reply (a Later never reaches here)
def reply(wid: Web) -> Http.Reply:
  match wid:
    case Now{status, headers, body}:
      Http.Reply{status, headers, body}
    case Later{id, name, args}:
      Http.Reply{500, [], "ezmcp: a tool call was not run"}
