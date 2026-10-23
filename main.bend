# ezmcp: Model Context Protocol servers and clients for Bend 2, revisions
# 2025-03-26, 2025-06-18 and 2025-11-25
#
# A server is a name, a version, instructions and a tool table; a runner
# (String -> Json -> IO(Rpc.Out)) runs a tool by name on its arguments and
# answers `ok` of a tool result, or `refuse` with a JSON-RPC error. ezmcp serves it over streamable HTTP (on ezhttp)
# or stdio, and answers initialize, ping, tools/list and tools/call itself.
# The client side builds requests and reads replies over HTTP. This file is
# the whole public interface; everything under src/ is internal, except the
# types src/server.bend, src/rpc.bend and src/web.bend name.
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import 0xedb2120a04a47dc18c3a756ec7c62750/src/http.bend as Http
import ./src/rpc.bend as Rpc
import ./src/server.bend as Server
import ./src/web.bend as Web
import ./src/client.bend as Client
import ./src/io.bend as Io

# --- servers ---

# a tool: its name, a description for the model, and the JSON Schema of its
# arguments (an object schema)
def tool(name: String, description: String, input: Value.Json) -> Server.Tool:  # noqa: L001 the Server.Tool constructor
  Server.Tool{name, description, input}

# a server: name and version (serverInfo), instructions for the client ("" for
# none), and its tools in the order tools/list shows them
def server(  # noqa: L001 the Server.Server constructor
  name: String,
  version: String,
  instructions: String,
  tools: List<&2, Server.Tool>
) -> Server.Server:
  Server.Server{name, version, instructions, tools}

# the latest protocol revision ezmcp speaks
def latest() -> String:  # noqa: L001 re-export of Server.latest
  Server.latest()

# the protocol revisions ezmcp speaks, oldest first
def revisions() -> List<&2, String>:  # noqa: L001 re-export of Server.revisions
  Server.revisions()

# what a server does with one message's text, read by revision `rev`: Quiet
# (send nothing), Send or Fault (send this reply; a Fault is a message it
# could not accept), Run (run a tool, then send `ran` of its result), or,
# under 2025-03-26, Batch (do each of its acts, then send `batch.reply` of
# their replies). For a transport of your own
def step(srv: Server.Server, rev: String, text: String) -> Server.Act:  # noqa: L001 re-export of Server.step
  Server.step(srv, rev, text)

# `step`'s act, and the revision a stream's next message is read by: the one
# an initialize was answered with, else `rev`. For a stream transport of your
# own, which starts at `latest()`
def turn(srv: Server.Server, rev: String, text: String) -> Server.Turn:  # noqa: L001 re-export of Server.turn
  Server.turn(srv, rev, text)

# the reply to a tool call with this id under revision `rev`, once the
# runner answered (2025-03-26 leaves structuredContent out)
def ran(rev: String, id: Value.Json, out: Rpc.Out) -> Value.Json:  # noqa: L001 re-export of Server.ran
  Server.ran(rev, id, out)

# what a batch sends back, from its acts' replies in order (None for an act
# with none): nothing when none has one, else their array
def batch.reply(replies: List<&2, Maybe<&2, Value.Json>>) -> Maybe<&2, Value.Json>:
  Server.batch.reply(replies)

# --- what a runner answers ---

# a runner's answer for a tool that ran: its tool result, which may itself
# report a failure with `isError` (`result.error`)
def ok(result: Value.Json) -> Rpc.Out:  # noqa: L001 the Rpc.Ok constructor
  Rpc.Ok{result}

# a runner's answer for a call it refuses as a protocol error: a JSON-RPC
# error with this code and message instead of a tool result
# (server/tools#error-handling)
def refuse(code: Rpc.Code, message: String) -> Rpc.Out:  # noqa: L001 the Rpc.Err constructor
  Rpc.Err{code, message}

# refuse with -32602 Invalid params, as for arguments that do not match the
# tool's input schema
def refuse.params(message: String) -> Rpc.Out:
  Rpc.Err{Rpc.InvalidParams{}, message}

# refuse with -32603 Internal error, as for a server that cannot run the tool
def refuse.internal(message: String) -> Rpc.Out:
  Rpc.Err{Rpc.InternalError{}, message}

# --- tool results ---

# a text content block
def text(text2: String) -> Value.Json:  # noqa: L001 re-export of Server.text
  Server.text(text2)

# a tool result from content blocks; is_error flags a tool that failed, so
# the model sees the failure (server/tools#error-handling)
def result(blocks: List<&2, Value.Json>, is_error: Bool) -> Value.Json:  # noqa: L001 re-export of Server.result
  Server.result(blocks, is_error)

# a tool result of one text block
def result.text(text: String) -> Value.Json:
  Server.result([Server.text(text)], False{})

# a failed tool's result: one text block, isError true
def result.error(text: String) -> Value.Json:
  Server.result([Server.text(text)], True{})

# a tool result with structured content, and its JSON text as a text block;
# a 2025-03-26 client gets the text block alone
def result.json(val: Value.Json) -> Value.Json:
  Server.structured(val, False{})

# --- streamable HTTP ---

# what the HTTP transport decides for one request to an endpoint at `path`
# that allows the browser origins listed: a reply now, or a tool to run
def http.decide(
  srv: Server.Server,
  path: String,
  origins: List<&2, String>,
  req: Http.Request
) -> Web.Web:
  Web.decide(srv, path, origins, req)

# one request to the MCP endpoint at `path`, as an ezhttp IO handler, for a
# server that serves other paths too
def http.handle(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  req: Http.Request
) -> IO(Http.Reply):
  Io.http.handle(run, srv, path, origins, req)

# serve the endpoint on host:port for `limit` connections, each on its own
# fork with no limit on how many at once, then stop once every connection is
# closed
def http.serve(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  host: String,
  port: U32,
  limit: U32
) -> IO(Unit):
  Io.http.serve(run, srv, path, origins, host, port, limit)

# serve the endpoint on host:port until the process is stopped, each
# connection on its own fork with no limit on how many at once
@unsafe def http.serve_forever(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  host: String,
  port: U32
) -> IO(Unit):
  Io.http.serve_forever(run, srv, path, origins, host, port)

# --- with a context ---
#
# A runner passed as `~run` is a closed template, so it cannot capture a
# value read at run time (arguments, environment, a base URL). These take a
# context `ctx` of any Data type `C` and hand it to the runner on every
# call: `run(ctx, name, args)`.

# one request to the MCP endpoint at `path`, its runner given `ctx`
def http.handle_with(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  req: Http.Request
) -> IO(Http.Reply):
  Io.http.handle_with(C, run, srv, path, origins, ctx, req)

# serve the endpoint on host:port for `limit` connections, its runner given
# `ctx`, each connection on its own fork and at most `max` at once (0: no
# limit; 1: one at a time), then stop once every connection is closed
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
  max: U32
) -> IO(Unit):
  Io.http.serve_with(C, run, srv, path, origins, ctx, host, port, limit, max)

# serve the endpoint on host:port, its runner given `ctx`, each connection on
# its own fork and at most `max` at once (0: no limit; 1: one at a time),
# until the process is stopped
@unsafe def http.serve_forever_with(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  +ctx: C,
  host: String,
  port: U32,
  max: U32
) -> IO(Unit):
  Io.http.serve_forever_with(C, run, srv, path, origins, ctx, host, port, max)

# serve stdin and stdout, its runner given `ctx`, until stdin ends
@unsafe def stdio.serve_with(
  ~C: Data,
  ~run: C -> String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server,
  +ctx: C
) -> IO(Unit):
  Io.stdio.serve_with(C, run, srv, ctx)

# --- stdio ---

# serve newline-delimited JSON-RPC on stdin and stdout until stdin ends;
# write logs with IO.print_err, never to stdout
@unsafe def stdio.serve(
  ~run: String -> Value.Json -> IO(Rpc.Out),
  ~srv: Server.Server
) -> IO(Unit):
  Io.stdio.serve(run, srv)

# --- client ---

# the initialize request, naming the client
def client.initialize(
  id: Value.Json,
  name: String,
  version: String
) -> Value.Json:
  Client.initialize(id, name, version)

# the notification to send once initialize succeeded
def client.initialized() -> Value.Json:
  Client.initialized()

# a tools/list request
def client.tools(id: Value.Json) -> Value.Json:
  Client.tools(id)

# a tools/call request
def client.call(id: Value.Json, name: String, args: Value.Json) -> Value.Json:
  Client.call(id, name, args)

# what a reply's JSON text says: Got{id, result}, Refused{id, code,
# message} or Unread{why}
def client.read(text: String) -> Rpc.Reply:
  Rpc.read(text)

# the revision an initialize result names, "" when it names none
def client.version(result: Value.Json) -> String:
  Client.version(result)

# POST a request to an MCP endpoint and read its reply, JSON or an event
# stream. `version` is the negotiated revision ("" before initialize); the
# timeout bounds connecting, sending and receiving
def client.ask(
  url: String,
  version: String,
  timeout_ms: U32,
  msg: Value.Json
) -> IO(Rpc.Reply):
  Io.client.ask(url, version, timeout_ms, msg)

# POST a notification; whether the server accepted it (any 2xx)
def client.tell(
  url: String,
  version: String,
  timeout_ms: U32,
  msg: Value.Json
) -> IO(Bool):
  Io.client.tell(url, version, timeout_ms, msg)
