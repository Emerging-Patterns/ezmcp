# ezmcp: Model Context Protocol (revision 2025-06-18) servers and clients for Bend 2
#
# A server is a name, a version, instructions and a tool table; a runner
# (String -> Json -> IO(Json)) runs a tool by name on its arguments and
# answers a tool result. ezmcp serves it over streamable HTTP (on ezhttp)
# or stdio, and answers initialize, ping, tools/list and tools/call itself.
# The client side builds requests and reads replies over HTTP. This file is
# the whole public interface; everything under src/ is internal, except the
# types src/server.bend, src/rpc.bend and src/web.bend name.
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import 0xa4d47e5f0f6044ac1a983d1b051fa47a/src/http.bend as Http
import ./src/rpc.bend as Rpc
import ./src/server.bend as Server
import ./src/web.bend as Web
import ./src/client.bend as Client
import ./src/io.bend as Io

# --- servers ---

# a tool: its name, a description for the model, and the JSON Schema of its
# arguments (an object schema)
def tool(name: String, description: String, input: Value.Json) -> Server.Tool:
  Server.Tool{name, description, input}

# a server: name and version (serverInfo), instructions for the client ("" for
# none), and its tools in the order tools/list shows them
def server(
  name: String,
  version: String,
  instructions: String,
  tools: List<&2, Server.Tool>
) -> Server.Server:
  Server.Server{name, version, instructions, tools}

# the protocol revision ezmcp speaks
def latest() -> String:
  Server.latest()

# what a server does with one message's text: Quiet (send nothing), Send or
# Fault (send this reply; a Fault is a message it could not accept), or Run
# (run a tool, then send `ran` of its result). For a transport of your own
def step(srv: Server.Server, text: String) -> Server.Act:
  Server.step(srv, text)

# the reply to a tool call with this id, once the tool ran
def ran(id: Value.Json, result: Value.Json) -> Value.Json:
  Server.ran(id, result)

# --- tool results ---

# a text content block
def text(text2: String) -> Value.Json:
  Server.text(text2)

# a tool result from content blocks; is_error flags a tool that failed, so
# the model sees the failure (server/tools#error-handling)
def result(blocks: List<&2, Value.Json>, is_error: Bool) -> Value.Json:
  Server.result(blocks, is_error)

# a tool result of one text block
def result.text(text: String) -> Value.Json:
  Server.result([Server.text(text)], False{})

# a failed tool's result: one text block, isError true
def result.error(text: String) -> Value.Json:
  Server.result([Server.text(text)], True{})

# a tool result with structured content, and its JSON text as a text block
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
  ~run: String -> Value.Json -> IO(Value.Json),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  req: Http.Request
) -> IO(Http.Reply):
  Io.http.handle(run, srv, path, origins, req)

# serve the endpoint on host:port for `limit` connections, then stop
def http.serve(
  ~run: String -> Value.Json -> IO(Value.Json),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  host: String,
  port: U32,
  limit: U32
) -> IO(Unit):
  Io.http.serve(run, srv, path, origins, host, port, limit)

# serve the endpoint on host:port until the process is stopped
@unsafe def http.serve_forever(
  ~run: String -> Value.Json -> IO(Value.Json),
  ~srv: Server.Server,
  ~path: String,
  ~origins: List<&2, String>,
  host: String,
  port: U32
) -> IO(Unit):
  Io.http.serve_forever(run, srv, path, origins, host, port)

# --- stdio ---

# serve newline-delimited JSON-RPC on stdin and stdout until stdin ends;
# write logs with IO.print_err, never to stdout
@unsafe def stdio.serve(
  ~run: String -> Value.Json -> IO(Value.Json),
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
