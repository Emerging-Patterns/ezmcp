# ezmcp/src/io: the effects. Every decision is src/web.bend's, src/line.bend's,
# src/server.bend's or src/client.bend's; this module reads, runs the tool
# runner, and writes, in order. It reaches ezhttp's socket effects, so no
# law file imports it.
#
# Trusted, not proved: this module decides nothing and acts on the pure
# modules' answers in order. The HTTP handler answers `Web.decide`'s reply,
# sent as `Web.reply` of it; for a tool call it runs the runner once with
# the name and arguments, then answers `Web.ran` of its result under the
# request's revision; for a batch it does each act in order (a reply taken
# as it is, a tool call run and its reply built with `Server.ran` under the
# request's revision, a notification or response taking none), then answers
# `Web.many` of `Server.batch.reply` of those replies. A serve `_with` a
# context hands that context, unchanged, to every runner call. Every HTTP
# serve is ezhttp's `http.serve_io_with` or `http.serve_forever_with` with
# one handler, the endpoint's: it takes the request as ezhttp's plain
# serves do (`server.plain`), answers `http.handle_with` of it, and hands
# the reply back as their text answer (`server.text`); `http.serve` and
# `http.serve_forever` are the `_with` serves with the context `Unit` and
# `max` 0; a serve `_from` is the `_with` serve whose handler decides with
# the server `srv(ctx)` reads from the context, on every request. The stdio
# loop starts at `Server.latest()`, reads stdin a chunk at a time, acts on
# every whole line of `Line.cut` in order under the revision the line
# before it left (`Line.line`'s turn: a reply written as `Line.frame`, a
# tool call run then its reply written, a batch's acts done in order and
# `Server.batch.reply` of their replies written when there is one), keeps
# the rest and the revision for the next read, acts on the rest as the last
# line when a read is empty (stdin ended), and then returns; it writes
# nothing else to stdout, and a failed read is written to stderr. The client
# POSTs the message's JSON text with `Client.headers`, reads the reply to a
# request with `Client.took`, and judges the reply to a notification with
# `Client.accepted`. This is IO sequencing: effects are foreign, so the
# checker cannot run an IO program and no law can state what happens after
# an effect. Every decision it acts on is one the laws under laws/ prove.
#
# Trusted, not proved: ezhttp (pinned in ez.lock.toml) parses HTTP/1.1
# requests and answers one that does not parse 400 itself (ezhttp's
# laws/BadRequestAnswers400.bend); hands a `_with` handler the context and
# the request decoded as UTF-8 (ezhttp's
# laws/WithServesGetOctetsAndContext.bend); serves each connection on its
# own fork, at most `max` at once, 0 for no limit (trusted in ezhttp's
# src/server.bend); finds a header case-insensitively (ezhttp's
# laws/FieldLookupIgnoresCase.bend); POSTs with a timeout (ezhttp's
# laws/DeadlineIsTimeout.bend, trusted in its src/client.bend); and
# `body_text` decodes a response's body as UTF-8 (ezhttp's
# laws/OctetsDecodeAsUtf8.bend). Its socket effects
# are foreign C and JS that no law here reaches. ezmcp keeps nothing between
# requests (it issues no session), so connections served at once share only
# the context, which nothing changes.
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import 0x7367809738fddd234b8d2bed772ad2cf/main.bend as Ez
import 0x7367809738fddd234b8d2bed772ad2cf/src/http.bend as Http
import 0x7367809738fddd234b8d2bed772ad2cf/src/client.bend as EzClient
import 0x7367809738fddd234b8d2bed772ad2cf/src/server.bend as EzServer
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

# --- serving HTTP ---
#
# ezhttp serves each connection on its own fork, reads and parses the
# request, answers one it answers itself (a request that does not parse),
# and calls the handler with the context for the rest (trusted above); the
# handler below is the endpoint's

# the endpoint's answer to one request ezhttp read, as its plain serves
# take one: the request as text in, a text reply out
def http.answer(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  req: EzServer.Req
) -> IO(EzServer.Answer):
  IO.bind(Http.Reply, EzServer.Answer,
    http.handle_with(C, run, srv, path, origins, ctx, EzServer.server.plain(req)),
    EzServer.server.text)

# serve `limit` connections, at most `max` at once (0: no limit), then stop
def http.serve_with(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  host: String,
  port: U32,
  limit: U32,
  +max: U32
) -> IO(Unit):
  Ez.http.serve_io_with(~C,
    ~(c => req => http.answer(C, run, srv, path, origins, c, req)), ctx, host,
    port, limit, max)

# serve until the process is stopped, at most `max` connections at once
# (0: no limit)
@unsafe def http.serve_forever_with(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  host: String,
  port: U32,
  +max: U32
) -> IO(Unit):
  Ez.http.serve_forever_with(~C,
    ~(c => req => http.answer(C, run, srv, path, origins, c, req)), ctx, host,
    port, max)

# --- with the server in the context ---
#
# A server passed as `~srv` is a closed template too, so one built at run
# time (from a document read at startup, say) rides in the context: `srv`
# reads it from the context on every request

# the endpoint's answer to one request ezhttp read, its server read from the
# context
def http.answer_from(
  ~C: Data,
  ~srv: C -> Server.Server,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  req: EzServer.Req
) -> IO(EzServer.Answer):
  IO.bind(Http.Reply, EzServer.Answer,
    http.web(C, run, ctx, Web.decide(srv(ctx), path, origins,
      EzServer.server.plain(req))),
    EzServer.server.text)

# serve `limit` connections, at most `max` at once (0: no limit), then stop
def http.serve_from(
  ~C: Data,
  ~srv: C -> Server.Server,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  host: String,
  port: U32,
  limit: U32,
  +max: U32
) -> IO(Unit):
  Ez.http.serve_io_with(~C,
    ~(c => req => http.answer_from(C, srv, run, path, origins, c, req)), ctx,
    host, port, limit, max)

# serve until the process is stopped, at most `max` connections at once
# (0: no limit)
@unsafe def http.serve_forever_from(
  ~C: Data,
  ~srv: C -> Server.Server,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  host: String,
  port: U32,
  +max: U32
) -> IO(Unit):
  Ez.http.serve_forever_with(~C,
    ~(c => req => http.answer_from(C, srv, run, path, origins, c, req)), ctx,
    host, port, max)

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

# serve `limit` connections, as many at once as arrive, then stop
def http.serve(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  host: String,
  port: U32,
  limit: U32
) -> IO(Unit):
  http.serve_with(~Unit, ~(_c => n => a => run(n, a)), srv, path, origins,
    Unit{}, host, port, limit, 0)

# serve until the process is stopped, as many connections at once as arrive
@unsafe def http.serve_forever(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  host: String,
  port: U32
) -> IO(Unit):
  http.serve_forever_with(~Unit, ~(_c => n => a => run(n, a)), srv, path,
    origins, Unit{}, host, port, 0)

# --- stdio ---

# up to `max` bytes from file descriptor 0, as one read(2) returns them;
# empty at the end of input
#
# Trusted, not proved: `ezmcp.stdin(max)` (`src/effs/stdin.c`,
# `src/effs/stdin.js`) answers the bytes one `read(2)` of file descriptor 0
# returns, at most `max`, an empty list at the end of input, or
# `Fail{(errno, message)}`; it reads the descriptor itself, so it works
# whatever stdin is (a pipe, a file, a socket). Base's `IO.write` writes its
# text to stdout in order, and `IO.print_err` to stderr. They are foreign C
# and JS: ezmcp's own over `read(2)`, and Bend's runtime (`effs/write.c`,
# `effs/print_err.c`), which no law reaches. Base has no stdin, and opening
# `/dev/stdin` fails with ENXIO when stdin is a socket, as it is for a
# server Node spawns.
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
    case EzClient.Response{status, +headers, reason, bytes}:
      Client.took(status, Http.headers.find(headers, "Content-Type"),
        Ez.body_text(bytes))

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
    case EzClient.Response{status, headers, reason, bytes}:
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
