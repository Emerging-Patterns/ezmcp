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
import 0xa4d47e5f0f6044ac1a983d1b051fa47a/src/server.bend as EzServer
import 0xa4d47e5f0f6044ac1a983d1b051fa47a/src/step.bend as EzStep
import ./rpc.bend as Rpc
import ./server.bend as Server
import ./web.bend as Web
import ./line.bend as Line
import ./client.bend as Client

# --- running acts ---

# one element of a batch, under revision `rev`: its reply, after running its
# tool when it is a tool call; none for a notification or a response
def act.reply(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  +ctx: C,
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
      IO.bind(Rpc.Out, Maybe<&2, Value.Json>, run(ctx, name, args),
        out => IO.pure(Maybe<&2, Value.Json>, Some{Server.ran(rev, id, out)}))
    case Server.Batch{acts}:
      IO.pure(Maybe<&2, Value.Json>, None{})

# every element of a batch, in order
def act.all(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  +ctx: C,
  +rev: String,
  acts: List<&2, Server.Act>
) -> IO(List<&2, Maybe<&2, Value.Json>>):
  match acts:
    case []:
      IO.pure(List<&2, Maybe<&2, Value.Json>>, [])
    case a <> rest:
      IO.bind(Maybe<&2, Value.Json>, List<&2, Maybe<&2, Value.Json>>,
        act.reply(C, run, ctx, rev, a),
        r => IO.bind(List<&2, Maybe<&2, Value.Json>>,
          List<&2, Maybe<&2, Value.Json>>, act.all(C, run, ctx, rev, rest),
          rs => IO.pure(List<&2, Maybe<&2, Value.Json>>, r <> rs)))

# --- streamable HTTP ---

# act on the transport's decision: reply now, or run the tool and reply
# with its result, or run a batch's acts and reply with their replies
def http.web(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  +ctx: C,
  wid: Web.Web
) -> IO(Http.Reply):
  match wid:
    case Web.Now{status, headers, body}:
      IO.pure(Http.Reply, Http.Reply{status, headers, body})
    case Web.Later{rev, id, name, args}:
      IO.bind(Rpc.Out, Http.Reply, run(ctx, name, args),
        out => IO.pure(Http.Reply, Web.reply(Web.ran(rev, id, out))))
    case Web.Many{+rev, acts}:
      IO.bind(List<&2, Maybe<&2, Value.Json>>, Http.Reply,
        act.all(C, run, ctx, rev, acts),
        rs => IO.pure(Http.Reply, Web.reply(Web.many(Server.batch.reply(rs)))))

# one HTTP request to a server's endpoint at `path`
def http.handle_with(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  req: Http.Request
) -> IO(Http.Reply):
  http.web(C, run, ctx, Web.decide(srv, path, origins, req))

# --- serving HTTP with a context ---
#
# ezhttp's serve loops take a closed handler, which cannot carry a value
# read at run time, so the loops below are ezhttp's serve_io and
# serve_forever (its src/server.bend) with the context passed along; every
# read, write and step of a connection is still ezhttp's (MCP-TRUST-2)

# answer one request ezhttp read: its own reply, or the endpoint's
def http.step(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  sock: Socket,
  +method: String,
  step: EzStep.Step
) -> IO(Unit):
  match step:
    case EzStep.Answer{reply}:
      EzServer.server.answer(sock, method, reply)
    case EzStep.Call{req}:
      IO.bind(Http.Reply, Unit, http.handle_with(C, run, srv, path, origins, ctx, req),
        reply => EzServer.server.answer(sock, method, reply))

# one connection's request, once read
def http.exchange.got(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  sock: Socket,
  got: EzStep.Got<Http.Request>
) -> IO(Unit):
  match got:
    case EzStep.Lost{line}:
      EzServer.server.lose(sock, line)
    case EzStep.Kept{+req}:
      http.step(C, run, srv, path, origins, ctx, sock, Http.method.of(req),
        EzStep.step.of(req))

def http.exchange.un(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  pair: Socket & EzStep.Got<Http.Request>
) -> IO(Unit):
  (sock, got) = pair
  http.exchange.got(C, run, srv, path, origins, ctx, sock, got)

# read one connection's request and answer it
def http.exchange(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  sock: Socket
) -> IO(Unit):
  IO.bind(Socket & EzStep.Got<Http.Request>, Unit, EzServer.server.read(sock),
    pair => http.exchange.un(C, run, srv, path, origins, ctx, pair))

# after an accept: a failure is logged and the loop pauses; a connection is
# served; then the loop goes on
def http.loop.got(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  again: Listener -> IO(Unit),
  lst: Listener,
  got: EzStep.Got<Socket>
) -> IO(Unit):
  match got:
    case EzStep.Lost{line}:
      IO.bind(Unit, Unit, IO.print_err(line), _u =>
        IO.bind(Unit, Unit, IO.sleep(EzServer.server.pause()), _v => again(lst)))
    case EzStep.Kept{sock}:
      IO.bind(Unit, Unit, http.exchange(C, run, srv, path, origins, ctx, sock),
        _u => again(lst))

def http.loop.cont(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  again: Listener -> IO(Unit),
  pair: Listener & EzStep.Got<Socket>
) -> IO(Unit):
  (lst, got) = pair
  http.loop.got(C, run, srv, path, origins, ctx, again, lst, got)

# accept and serve `fuel` connections, then close the listener
def http.loop.go(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  fuel: Nat,
  listener: Listener
) -> IO(Unit):
  match fuel:
    case 0n:
      Listener.close(listener)
    case 1n+f:
      IO.bind(Listener & EzStep.Got<Socket>, Unit, EzServer.server.accept(listener),
        pair => http.loop.cont(C, run, srv, path, origins, ctx,
          lst => http.loop.go(C, run, srv, path, origins, ctx, f, lst), pair))

# serve `limit` connections, then stop
def http.serve_with(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  host: String,
  port: U32,
  limit: U32
) -> IO(Unit):
  IO.bind(Listener, Unit, EzServer.server.listen(host, port),
    lst => http.loop.go(C, run, srv, path, origins, ctx, U32.to_nat(limit), lst))

# accept and serve connections until the process is stopped
@unsafe def http.forever.go(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  listener: Listener
) -> IO(Unit):
  IO.bind(Listener & EzStep.Got<Socket>, Unit, EzServer.server.accept(listener),
    pair => http.loop.cont(C, run, srv, path, origins, ctx,
      lst => http.forever.go(C, run, srv, path, origins, ctx, lst), pair))

# serve until the process is stopped
@unsafe def http.serve_forever_with(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  host: String,
  port: U32
) -> IO(Unit):
  IO.bind(Listener, Unit, EzServer.server.listen(host, port),
    lst => http.forever.go(C, run, srv, path, origins, ctx, lst))

# --- with no context ---

# one HTTP request to a server's endpoint at `path`
def http.handle(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  req: Http.Request
) -> IO(Http.Reply):
  http.handle_with(~Unit, ~(_c => n => a => run(n, a)), srv, path, origins,
    Unit{}, req)

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
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  +ctx: C,
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
      IO.bind(Rpc.Out, Unit, run(ctx, name, args),
        out => IO.write(Line.frame(Server.ran(rev, id, out))))
    case Server.Batch{acts}:
      IO.bind(List<&2, Maybe<&2, Value.Json>>, Unit, act.all(C, run, ctx, rev, acts),
        rs => stdio.batch(Server.batch.reply(rs)))

# act on a turn read by revision `rev`, then go on with the revision after it
def stdio.turn(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  +ctx: C,
  +rev: String,
  turn: Server.Turn,
  next: String -> IO(String)
) -> IO(String):
  match turn:
    case Server.Turn{act, after}:
      IO.bind(Unit, String, stdio.act(C, run, ctx, rev, act), _u => next(after))

# every whole line, in order, each read by the revision the line before it
# left; answers the revision the last one left
def stdio.lines(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  +ctx: C,
  lines: List<&2, List<&2, U32>>,
  +rev: String
) -> IO(String):
  match lines:
    case []:
      IO.pure(String, rev)
    case line <> rest:
      stdio.turn(C, run, ctx, rev, Line.line(srv, rev, line),
        after => stdio.lines(C, run, srv, ctx, rest, after))

# act on a cut's whole lines, then read on with its rest
def stdio.cut(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  +ctx: C,
  rev: String,
  again: List<&2, U32> -> String -> IO(Unit),
  cut: Line.Cut
) -> IO(Unit):
  match cut:
    case Line.Cut{lines, rest}:
      IO.bind(String, Unit, stdio.lines(C, run, srv, ctx, lines, rev),
        after => again(rest, after))

# after a read: an empty one is the end of stdin, and the bytes after the
# last newline are the last message; any other is cut into lines
def stdio.chunked(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  +ctx: C,
  rev: String,
  buf: List<&2, U32>,
  bytes: List<&2, U32>,
  again: List<&2, U32> -> String -> IO(Unit),
  empty: Bool
) -> IO(Unit):
  match empty:
    case True{}:
      IO.bind(String, Unit, stdio.lines(C, run, srv, ctx, [buf], rev),
        _r => IO.pure(Unit, Unit{}))
    case False{}:
      stdio.cut(C, run, srv, ctx, rev, again,
        Line.cut(List.append(&2, U32, buf, bytes)))

# after one read: a failure is logged to stderr and ends the loop
def stdio.got(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  +ctx: C,
  rev: String,
  buf: List<&2, U32>,
  again: List<&2, U32> -> String -> IO(Unit),
  res: Result<&1, &1, U32 & String, List<&2, U32>>
) -> IO(Unit):
  match res:
    case Fail{(_code, why)}:
      IO.print_err("ezmcp: stdin: " ++ why)
    case Done{+bytes}:
      stdio.chunked(C, run, srv, ctx, rev, buf, bytes, again,
        List.is_empty(&2, U32, bytes))

# read, act on every whole line, and read again until stdin ends; `rev` is
# the revision the next line is read by
@unsafe def stdio.loop(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  +ctx: C,
  buf: List<&2, U32>,
  rev: String
) -> IO(Unit):
  IO.bind(Result<&1, &1, U32 & String, List<&2, U32>>, Unit,
    ezmcp.stdin(stdio.chunk()),
    res => stdio.got(C, run, srv, ctx, rev, buf,
      rest => after => stdio.loop(C, run, srv, ctx, rest, after), res))

# serve newline-delimited JSON-RPC on stdin and stdout until stdin ends; a
# line is read by the latest revision until an initialize names another
@unsafe def stdio.serve_with(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  +ctx: C
) -> IO(Unit):
  stdio.loop(C, run, srv, ctx, [], Server.latest())

# serve newline-delimited JSON-RPC on stdin and stdout until stdin ends,
# with no context
@unsafe def stdio.serve(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server
) -> IO(Unit):
  stdio.serve_with(~Unit, ~(_c => n => a => run(n, a)), srv, Unit{})

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
