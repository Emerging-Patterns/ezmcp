# ezmcp/src/io: the effects. Every decision is src/web.bend's, src/line.bend's,
# src/server.bend's or src/client.bend's; this module reads, runs the tool
# runner, and writes, in order (MCP-TRUST-1). It reaches ezhttp's socket
# effects, so no law file imports it.
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import 0xa4d47e5f0f6044ac1a983d1b051fa47a/main.bend as Ez
import 0xa4d47e5f0f6044ac1a983d1b051fa47a/src/http.bend as Http
import 0xa4d47e5f0f6044ac1a983d1b051fa47a/src/client.bend as EzClient
import ./rpc.bend as Rpc
import ./server.bend as Server
import ./web.bend as Web
import ./line.bend as Line
import ./client.bend as Client

# --- running acts ---

# one element of a batch, under revision `rev`: its reply, after running its
# tool when it is a tool call; none for a notification or a response
def act.reply(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  +rev: String,
  act: Server.Act
) -> IO(Maybe<&2, Value.Json>):
  match act:
    case Server.Quiet{}:
      IO.pure(Maybe<&2, Value.Json>, None{})
    case Server.Send{reply}:
      IO.pure(Maybe<&2, Value.Json>, Some{reply})
    case Server.Fault{reply}:
      IO.pure(Maybe<&2, Value.Json>, Some{reply})
    case Server.Run{id, name, args}:
      IO.bind(Rpc.Out, Maybe<&2, Value.Json>, run(name, args),
        out => IO.pure(Maybe<&2, Value.Json>, Some{Server.ran(rev, id, out)}))
    case Server.Batch{acts}:
      IO.pure(Maybe<&2, Value.Json>, None{})

# every element of a batch, in order
def act.all(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  +rev: String,
  acts: List<&2, Server.Act>
) -> IO(List<&2, Maybe<&2, Value.Json>>):
  match acts:
    case []:
      IO.pure(List<&2, Maybe<&2, Value.Json>>, [])
    case a <> rest:
      IO.bind(Maybe<&2, Value.Json>, List<&2, Maybe<&2, Value.Json>>,
        act.reply(run, rev, a),
        r => IO.bind(List<&2, Maybe<&2, Value.Json>>,
          List<&2, Maybe<&2, Value.Json>>, act.all(run, rev, rest),
          rs => IO.pure(List<&2, Maybe<&2, Value.Json>>, r <> rs)))

# --- streamable HTTP ---

# act on the transport's decision: reply now, or run the tool and reply
# with its result, or run a batch's acts and reply with their replies
def http.web(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  wid: Web.Web
) -> IO(Http.Reply):
  match wid:
    case Web.Now{status, headers, body}:
      IO.pure(Http.Reply, Http.Reply{status, headers, body})
    case Web.Later{rev, id, name, args}:
      IO.bind(Rpc.Out, Http.Reply, run(name, args),
        out => IO.pure(Http.Reply, Web.reply(Web.ran(rev, id, out))))
    case Web.Many{+rev, acts}:
      IO.bind(List<&2, Maybe<&2, Value.Json>>, Http.Reply,
        act.all(run, rev, acts),
        rs => IO.pure(Http.Reply, Web.reply(Web.many(Server.batch.reply(rs)))))

# one HTTP request to a server's endpoint at `path`
def http.handle(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  req: Http.Request
) -> IO(Http.Reply):
  http.web(run, Web.decide(srv, path, origins, req))

# serve `limit` connections, then stop
def http.serve(
  ~run: String -> Value.Json -> IO(Rpc.Out),
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
  ~run: String -> Value.Json -> IO(Rpc.Out),
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

# a batch's replies: nothing when there are none, else one line
def stdio.batch(replies: Maybe<&2, Value.Json>) -> IO(Unit):
  match replies:
    case None{}:
      IO.pure(Unit, Unit{})
    case Some{batch}:
      IO.write(Line.frame(batch))

# act on one line's act, read by revision `rev`: write a reply as one line,
# or run the tool and write its reply, or run a batch's acts and write the
# array of their replies, or write nothing
def stdio.act(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  +rev: String,
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
      IO.bind(Rpc.Out, Unit, run(name, args),
        out => IO.write(Line.frame(Server.ran(rev, id, out))))
    case Server.Batch{acts}:
      IO.bind(List<&2, Maybe<&2, Value.Json>>, Unit, act.all(run, rev, acts),
        rs => stdio.batch(Server.batch.reply(rs)))

# act on a turn read by revision `rev`, then go on with the revision after it
def stdio.turn(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  +rev: String,
  turn: Server.Turn,
  next: String -> IO(String)
) -> IO(String):
  match turn:
    case Server.Turn{act, after}:
      IO.bind(Unit, String, stdio.act(run, rev, act), _u => next(after))

# every whole line, in order, each read by the revision the line before it
# left; answers the revision the last one left
def stdio.lines(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  lines: List<&2, List<&2, U32>>,
  +rev: String
) -> IO(String):
  match lines:
    case []:
      IO.pure(String, rev)
    case line <> rest:
      stdio.turn(run, rev, Line.line(srv, rev, line),
        after => stdio.lines(run, srv, rest, after))

# act on a cut's whole lines, then read on with its rest
def stdio.cut(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  rev: String,
  again: List<&2, U32> -> String -> IO(Unit),
  cut: Line.Cut
) -> IO(Unit):
  match cut:
    case Line.Cut{lines, rest}:
      IO.bind(String, Unit, stdio.lines(run, srv, lines, rev),
        after => again(rest, after))

# after a read: an empty one is the end of stdin, and the bytes after the
# last newline are the last message; any other is cut into lines
def stdio.chunked(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  rev: String,
  buf: List<&2, U32>,
  bytes: List<&2, U32>,
  again: List<&2, U32> -> String -> IO(Unit),
  empty: Bool
) -> IO(Unit):
  match empty:
    case True{}:
      IO.bind(String, Unit, stdio.lines(run, srv, [buf], rev),
        _r => IO.pure(Unit, Unit{}))
    case False{}:
      stdio.cut(run, srv, rev, again,
        Line.cut(List.append(&2, U32, buf, bytes)))

# after one read: a failure is logged to stderr and ends the loop
def stdio.got(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  rev: String,
  buf: List<&2, U32>,
  again: List<&2, U32> -> String -> IO(Unit),
  res: Result<&1, &1, U32 & String, List<&2, U32>>
) -> IO(Unit):
  match res:
    case Fail{(_code, why)}:
      IO.print_err("ezmcp: stdin: " ++ why)
    case Done{+bytes}:
      stdio.chunked(run, srv, rev, buf, bytes, again,
        List.is_empty(&2, U32, bytes))

# read, act on every whole line, and read again until stdin ends; `rev` is
# the revision the next line is read by
@unsafe def stdio.loop(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  buf: List<&2, U32>,
  rev: String
) -> IO(Unit):
  IO.bind(Result<&1, &1, U32 & String, List<&2, U32>>, Unit,
    ezmcp.stdin(stdio.chunk()),
    res => stdio.got(run, srv, rev, buf,
      rest => after => stdio.loop(run, srv, rest, after), res))

# serve newline-delimited JSON-RPC on stdin and stdout until stdin ends; a
# line is read by the latest revision until an initialize names another
@unsafe def stdio.serve(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server
) -> IO(Unit):
  stdio.loop(run, srv, [], Server.latest())

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
