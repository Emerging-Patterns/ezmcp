# ezmcp/src/server: an MCP server's decisions, with no IO. One message's
# text in, an act out: a reply to send, nothing to send, or a tool call for
# the transport to run (src/io.bend) before it replies with `ran`.
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ./rpc.bend as Rpc

# one tool: its name, what it does, and the JSON Schema of its arguments
type Tool is Data:
  Tool{name: String, description: String, input: Value.Json}

# a server: its name and version, instructions for the client (empty for
# none), and its tools
type Server is Data:
  Server{name: String, version: String, instructions: String,
    tools: List<&2, Tool>}

# what a server does with one message
type Act is Data:
  Quiet{}
  Send{reply: Value.Json}
  Fault{reply: Value.Json}
  Run{id: Value.Json, name: String, args: Value.Json}

# how a method ends: an outcome now, or a tool to run
type Step is Data:
  Now{out: Rpc.Out}
  Call{name: String, args: Value.Json}

# the methods a server answers
type Method is Data:
  Initialize{}
  Ping{}
  ListTools{}
  CallTool{}
  Other{}

# --- protocol versions ---

# the revision ezmcp speaks
def latest() -> String:
  "2025-06-18"

# whether ezmcp speaks a revision
def supported(val: String) -> Bool:
  String.eq(val, latest())

# the revision a server answers to the one a client asks for: the same when
# it is supported, else the latest (basic/lifecycle#version-negotiation)
def negotiate.of(val: String, ok: Bool) -> String:
  match ok:
    case True{}:
      val
    case False{}:
      latest()

# the revision answered to an initialize request's, if it names one
def negotiate(asked: Maybe<&2, String>) -> String:
  match asked:
    case None{}:
      latest()
    case Some{+v}:
      negotiate.of(v, supported(v))

# --- initialize ---

# the capabilities a tool table declares: tools when there is one, with
# listChanged false, since the table never changes
def capabilities(tools: List<&2, Tool>) -> Value.Json:
  match tools:
    case []:
      Json.obj([])
    case t <> rest:
      Json.obj([("tools", Json.obj([("listChanged", Json.bool(False{}))]))])

def init.info(name: String, version: String) -> Value.Json:
  Json.obj([("name", Json.str(name)), ("version", Json.str(version))])

# the instructions member, when there are any
def init.extra(
  instructions: String,
  empty: Bool
) -> List<&1, String & Value.Json>:
  match empty:
    case True{}:
      []
    case False{}:
      [("instructions", Json.str(instructions))]

# the members of an initialize result
def init.with(
  version: String,
  caps: Value.Json,
  info: Value.Json,
  +instructions: String
) -> Value.Json:
  Json.obj(List.append(&1, String & Value.Json,
    [("protocolVersion", Json.str(version)), ("capabilities", caps),
      ("serverInfo", info)],
    init.extra(instructions, String.is_empty(instructions))))

# the result of initialize (basic/lifecycle#initialization)
def init(srv: Server, params: Value.Json) -> Value.Json:
  match srv:
    case Server{name, version, instructions, tools}:
      init.with(negotiate(Json.as_str(Json.get(params, "protocolVersion"))),
        capabilities(tools), init.info(name, version), instructions)

# --- tools ---

# one tool as tools/list shows it (server/tools#tool)
def tool.json(tail: Tool) -> Value.Json:
  match tail:
    case Tool{name, description, input}:
      Json.obj([("name", Json.str(name)), ("description", Json.str(description)),
        ("inputSchema", input)])

def tool.all(tools: List<&2, Tool>) -> List<&2, Value.Json>:
  match tools:
    case []:
      []
    case t <> rest:
      tool.json(t) <> tool.all(rest)

# the result of tools/list: every tool, in order, on one page
def list(srv: Server) -> Value.Json:
  match srv:
    case Server{name, version, instructions, tools}:
      Json.obj([("tools", Json.arr(tool.all(tools)))])

# true at a hit, else the rest of the search
def known.or(hit: Bool, rest: Unit -> Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      rest(Unit{})

# whether a tool table has a tool by this name
def known(tools: List<&2, Tool>, +name: String) -> Bool:
  match tools:
    case []:
      False{}
    case Tool{tname, _desc, _input} <> rest:
      known.or(String.eq(tname, name), _u => known(rest, name))

# an invalid-params outcome
def invalid(message: String) -> Step:
  Now{Rpc.Err{Rpc.InvalidParams{}, message}}

# the arguments of a call: absent is no arguments, an object is passed on,
# anything else is invalid
def call.args(+name: String, has: Bool, +args: Value.Json) -> Step:
  match has:
    case False{}:
      Call{name, Json.obj([])}
    case True{}:
      Bool.pick(Step, Json.is_obj(args), Call{name, args},
        invalid("tools/call: arguments must be an object"))

def call.known(+name: String, +params: Value.Json, hit: Bool) -> Step:
  match hit:
    case False{}:
      invalid("Unknown tool: " ++ name)
    case True{}:
      call.args(name, Json.has(params, "arguments"),
        Json.get(params, "arguments"))

def call.named(
  tools: List<&2, Tool>,
  +params: Value.Json,
  name: Maybe<&2, String>
) -> Step:
  match name:
    case None{}:
      invalid("tools/call: params.name must be a string")
    case Some{+n}:
      call.known(n, params, known(tools, n))

# tools/call: a known tool with object arguments is a call to run; anything
# else is an invalid-params error (server/tools#error-handling)
def call(srv: Server, +params: Value.Json) -> Step:
  match srv:
    case Server{name, version, instructions, tools}:
      call.named(tools, params, Json.as_str(Json.get(params, "name")))

# --- dispatch ---

def method.of(+meth: String) -> Method:
  Bool.pick(Method, String.eq(meth, "initialize"), Initialize{},
    Bool.pick(Method, String.eq(meth, "ping"), Ping{},
      Bool.pick(Method, String.eq(meth, "tools/list"), ListTools{},
        Bool.pick(Method, String.eq(meth, "tools/call"), CallTool{}, Other{}))))

def dispatch.of(
  srv: Server,
  meth: String,
  params: Value.Json,
  which: Method
) -> Step:
  match which:
    case Initialize{}:
      Now{Rpc.Ok{init(srv, params)}}
    case Ping{}:
      Now{Rpc.Ok{Json.obj([])}}
    case ListTools{}:
      Now{Rpc.Ok{list(srv)}}
    case CallTool{}:
      call(srv, params)
    case Other{}:
      Now{Rpc.Err{Rpc.MethodNotFound{}, "Method not found: " ++ meth}}

# how a request for a method ends
def dispatch(srv: Server, +meth: String, params: Value.Json) -> Step:
  dispatch.of(srv, meth, params, method.of(meth))

# a request's step as an act
def answer(id: Value.Json, text: Step) -> Act:
  match text:
    case Now{out}:
      Send{Rpc.reply(id, out)}
    case Call{name, args}:
      Run{id, name, args}

# what a server does with one classified message: a request is answered, a
# notification or a response is not, an invalid request is a fault
def handle(srv: Server, msg: Rpc.Msg) -> Act:
  match msg:
    case Rpc.Ask{id, m, params}:
      answer(id, dispatch(srv, m, params))
    case Rpc.Tell{m, params}:
      Quiet{}
    case Rpc.Answer{id}:
      Quiet{}
    case Rpc.Junk{id, why}:
      Fault{Rpc.reply(id, Rpc.Err{Rpc.InvalidRequest{}, why})}

# the fault for text that is not JSON (JSON-RPC 2.0 §5.1)
def unparsed() -> Act:
  Fault{Rpc.reply(Json.null(),
    Rpc.Err{Rpc.ParseError{}, "Parse error"})}

# what a server does with a decoded message, or with text that was not JSON
def parsed(srv: Server, meth: Maybe<&2, Value.Json>) -> Act:
  match meth:
    case None{}:
      unparsed()
    case Some{v}:
      handle(srv, Rpc.classify(v))

# what a server does with one message's text
def step(srv: Server, text: String) -> Act:
  parsed(srv, Json.parse(text))

# the reply to a tool call, once it ran
def ran(id: Value.Json, result: Value.Json) -> Value.Json:
  Rpc.reply(id, Rpc.Ok{result})

# --- tool results (server/tools#tool-result) ---

# a text content block
def text(text2: String) -> Value.Json:
  Json.obj([("type", Json.str("text")), ("text", Json.str(text2))])

# a tool result from content blocks, flagged when the tool failed
def result(blocks: List<&2, Value.Json>, bad: Bool) -> Value.Json:
  Json.obj([("content", Json.arr(blocks)), ("isError", Json.bool(bad))])

# a tool result with structured content, and its JSON text as a text block
def structured(+val: Value.Json, bad: Bool) -> Value.Json:
  Json.obj([("content", Json.arr([text(Json.print(val))])),
    ("structuredContent", val), ("isError", Json.bool(bad))])
