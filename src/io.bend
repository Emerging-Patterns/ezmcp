# ezmcp/src/io: the effects. Every decision is src/web.bend's, src/line.bend's,
# src/server.bend's or src/client.bend's; this module reads, runs the tool
# runner, and writes, in order (MCP-TRUST-1). It reaches ezhttp's socket
# effects, so no law file imports it.
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import 0xd3f9c1f02240edb63fd4a109ceb8fa74/main.bend as Ez
import 0xd3f9c1f02240edb63fd4a109ceb8fa74/src/http.bend as Http
import 0xd3f9c1f02240edb63fd4a109ceb8fa74/src/client.bend as EzClient
import ./rpc.bend as Rpc
import ./server.bend as Server
import ./web.bend as Web
import ./line.bend as Line
import ./client.bend as Client

# --- streamable HTTP ---

# act on the transport's decision: reply now, or run the tool and reply
# with its result
def http.web(
  ~run: String -> Value.Json -> IO(Value.Json),
  wid: Web.Web
) -> IO(Http.Reply):
  match wid:
    case Web.Now{status, headers, body}:
      IO.pure(Http.Reply, Http.Reply{status, headers, body})
    case Web.Later{id, name, args}:
      IO.bind(Value.Json, Http.Reply, run(name, args),
        result => IO.pure(Http.Reply, Web.reply(Web.ran(id, result))))

# one HTTP request to a server's endpoint at `path`
def http.handle(
  ~run: String -> Value.Json -> IO(Value.Json),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  req: Http.Request
) -> IO(Http.Reply):
  http.web(run, Web.decide(srv, path, origins, req))

# serve `limit` connections, then stop
def http.serve(
  ~run: String -> Value.Json -> IO(Value.Json),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  host: String,
  port: U32,
  limit: U32
) -> IO(Unit):
  Ez.http.serve_io(~(req => http.handle(run, srv, path, origins, req)), host,
    port, limit)

# serve until the process is stopped
@unsafe def http.serve_forever(
  ~run: String -> Value.Json -> IO(Value.Json),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  host: String,
  port: U32
) -> IO(Unit):
  Ez.http.serve_forever(~(req => http.handle(run, srv, path, origins, req)),
    host, port)

# --- stdio ---

# up to `max` bytes from file descriptor 0, as one read(2) returns them;
# empty at the end of input (MCP-TRUST-5)
def ezmcp.stdin(max: U32) -> IO(Result<&1, &1, U32 & String, List<&2, U32>>):
  import "./effs/stdin.c"
  import "./effs/stdin.js"

# bytes one read of stdin asks for
def stdio.chunk() -> U32:
  65536

# act on one line's act: write a reply as one line, or run the tool and
# write its reply, or write nothing
def stdio.act(
  ~run: String -> Value.Json -> IO(Value.Json),
  act: Server.Act
) -> IO(Unit):
  match act:
    case Server.Quiet{}:
      IO.pure(Unit, Unit{})
    case Server.Send{reply}:
      IO.write(Line.frame(reply))
    case Server.Fault{reply}:
      IO.write(Line.frame(reply))
    case Server.Run{id, name, args}:
      IO.bind(Value.Json, Unit, run(name, args),
        result => IO.write(Line.frame(Server.ran(id, result))))

# every whole line, in order
def stdio.lines(
  ~run: String -> Value.Json -> IO(Value.Json),
  ~srv: Server.Server,
  lines: List<&2, List<&2, U32>>
) -> IO(Unit):
  match lines:
    case []:
      IO.pure(Unit, Unit{})
    case line <> rest:
      IO.bind(Unit, Unit, stdio.act(run, Line.line(srv, line)),
        _u => stdio.lines(run, srv, rest))

# act on a cut's whole lines, then read on with its rest
def stdio.cut(
  ~run: String -> Value.Json -> IO(Value.Json),
  ~srv: Server.Server,
  again: List<&2, U32> -> IO(Unit),
  cut: Line.Cut
) -> IO(Unit):
  match cut:
    case Line.Cut{lines, rest}:
      IO.bind(Unit, Unit, stdio.lines(run, srv, lines), _u => again(rest))

# after a read: an empty one is the end of stdin, and the bytes after the
# last newline are the last message; any other is cut into lines
def stdio.chunked(
  ~run: String -> Value.Json -> IO(Value.Json),
  ~srv: Server.Server,
  buf: List<&2, U32>,
  bytes: List<&2, U32>,
  again: List<&2, U32> -> IO(Unit),
  empty: Bool
) -> IO(Unit):
  match empty:
    case True{}:
      stdio.lines(run, srv, [buf])
    case False{}:
      stdio.cut(run, srv, again, Line.cut(List.append(&2, U32, buf, bytes)))

# after one read: a failure is logged to stderr and ends the loop
def stdio.got(
  ~run: String -> Value.Json -> IO(Value.Json),
  ~srv: Server.Server,
  buf: List<&2, U32>,
  again: List<&2, U32> -> IO(Unit),
  res: Result<&1, &1, U32 & String, List<&2, U32>>
) -> IO(Unit):
  match res:
    case Fail{(_code, why)}:
      IO.print_err("ezmcp: stdin: " ++ why)
    case Done{+bytes}:
      stdio.chunked(run, srv, buf, bytes, again,
        List.is_empty(&2, U32, bytes))

# read, act on every whole line, and read again until stdin ends
@unsafe def stdio.loop(
  ~run: String -> Value.Json -> IO(Value.Json),
  ~srv: Server.Server,
  buf: List<&2, U32>
) -> IO(Unit):
  IO.bind(Result<&1, &1, U32 & String, List<&2, U32>>, Unit,
    ezmcp.stdin(stdio.chunk()),
    res => stdio.got(run, srv, buf, rest => stdio.loop(run, srv, rest), res))

# serve newline-delimited JSON-RPC on stdin and stdout until stdin ends
@unsafe def stdio.serve(
  ~run: String -> Value.Json -> IO(Value.Json),
  ~srv: Server.Server
) -> IO(Unit):
  stdio.loop(run, srv, [])

# --- client ---

# what an ezhttp response to a request says
def client.took(res: EzClient.Response) -> Rpc.Reply:
  match res:
    case EzClient.Err{why}:
      Rpc.Unread{why}
    case EzClient.Response{status, +headers, body}:
      Client.took(status, Http.headers.find(headers, "Content-Type"), body)

# POST one request and read its reply
def client.ask(
  url: String,
  version: String,
  timeout_ms: U32,
  msg: Value.Json
) -> IO(Rpc.Reply):
  IO.bind(EzClient.Response, Rpc.Reply,
    Ez.http.post_opts(url, Client.headers(version), Ez.text_body(Json.print(msg)),
      timeout_ms),
    r => IO.pure(Rpc.Reply, client.took(r)))

def client.sent(res: EzClient.Response) -> Bool:
  match res:
    case EzClient.Err{why}:
      False{}
    case EzClient.Response{status, headers, body}:
      Client.accepted(status)

# POST one notification; whether the server accepted it
def client.tell(
  url: String,
  version: String,
  timeout_ms: U32,
  msg: Value.Json
) -> IO(Bool):
  IO.bind(EzClient.Response, Bool,
    Ez.http.post_opts(url, Client.headers(version), Ez.text_body(Json.print(msg)),
      timeout_ms),
    r => IO.pure(Bool, client.sent(r)))
