# ezmcp/src/server: an MCP server's decisions, with no IO. One message's
# text in, under the protocol revision the transport reads it by, an act
# out: a reply to send, nothing to send, a tool call for the transport to
# run (src/io.bend) before it replies with `ran`, or, under 2025-03-26, a
# batch of those.
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

# what a server does with one message; a Batch's acts are its elements',
# in order, and none of them is a Batch
type Act is Data:
  Quiet{}
  Send{reply: Value.Json}
  Fault{reply: Value.Json}
  Run{id: Value.Json, name: String, args: Value.Json}
  Batch{acts: List<&2, Act>}

# what a server does with one message, and the revision the messages after
# it are read by on the same stream
type Turn is Data:
  Turn{act: Act, rev: String}

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

# the latest revision ezmcp speaks
def latest() -> String:
  "2025-11-25"

# the oldest: the one JSON-RPC batches belong to, and the one a server
# assumes for an HTTP request that names none
def oldest() -> String:
  "2025-03-26"

# the revisions ezmcp speaks, oldest first
def revisions() -> List<&2, String>:
  [oldest(), "2025-06-18", latest()]

# whether ezmcp speaks a revision
def supported(+val: String) -> Bool:
  Bool.or(String.eq(val, oldest()),
    Bool.or(String.eq(val, "2025-06-18"), String.eq(val, latest())))

# whether a revision receives JSON-RPC batches: 2025-03-26 does, and
# 2025-06-18 removed them
def batches(rev: String) -> Bool:
  String.eq(rev, oldest())

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

# --- the revision of a stream ---

def session.ask(rev: String, params: Value.Json, init: Bool) -> String:
  match init:
    case True{}:
      negotiate(Json.as_str(Json.get(params, "protocolVersion")))
    case False{}:
      rev

# the revision the messages after this one are read by: the one the server
# answers an initialize request with, else the one they were read by
def session(rev: String, msg: Rpc.Msg) -> String:
  match msg:
    case Rpc.Ask{id, +m, params}:
      session.ask(rev, params, String.eq(m, "initialize"))
    case Rpc.Tell{m, params}:
      rev
    case Rpc.Answer{id}:
      rev
    case Rpc.Junk{id, why}:
      rev

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

# --- batches (2025-03-26) ---

def batch.init(id: Value.Json, msg: Rpc.Msg, init: Bool, srv: Server) -> Act:
  match init:
    case True{}:
      Send{Rpc.reply(id, Rpc.Err{Rpc.InvalidRequest{},
        "Invalid Request: initialize must not be part of a batch"})}
    case False{}:
      handle(srv, msg)

# what a server does with one element of a batch: what it does with the
# message alone, except that initialize is an invalid request
# (2025-03-26/basic/lifecycle#initialization)
def batch.one(srv: Server, +msg: Rpc.Msg) -> Act:
  match msg:
    case Rpc.Ask{+id, +m, params}:
      batch.init(id, msg, String.eq(m, "initialize"), srv)
    case other:
      handle(srv, other)

# every element's act, in order
def batch.all(+srv: Server, items: List<&2, Value.Json>) -> List<&2, Act>:
  match items:
    case []:
      []
    case i <> rest:
      batch.one(srv, Rpc.classify(i)) <> batch.all(srv, rest)

# what a server does with a batch: an empty one is one invalid request
# (JSON-RPC §6); any other is a batch of its elements' acts
def batch(srv: Server, items: List<&2, Value.Json>) -> Act:
  match items:
    case []:
      Fault{Rpc.reply(Json.null(), Rpc.Err{Rpc.InvalidRequest{},
        "Invalid Request: empty batch"})}
    case i <> rest:
      Batch{batch.all(srv, i <> rest)}

# the replies of a batch's elements that have one, in order
def batch.some(replies: List<&2, Maybe<&2, Value.Json>>) -> List<&2, Value.Json>:
  match replies:
    case []:
      []
    case None{} <> rest:
      batch.some(rest)
    case Some{r} <> rest:
      r <> batch.some(rest)

def batch.gather(replies: List<&2, Value.Json>) -> Maybe<&2, Value.Json>:
  match replies:
    case []:
      None{}
    case r <> rest:
      Some{Json.arr(r <> rest)}

# what a batch sends back: nothing when no element has a reply, else the
# array of the replies (JSON-RPC §6)
def batch.reply(replies: List<&2, Maybe<&2, Value.Json>>) -> Maybe<&2, Value.Json>:
  batch.gather(batch.some(replies))

# --- a message's turn ---

# a message's act, and the revision after it
def turn.msg(srv: Server, rev: String, +msg: Rpc.Msg) -> Turn:
  Turn{handle(srv, msg), session(rev, msg)}

# a decoded value: a batch when it is an array and the revision receives
# batches, else one message
def turn.value(srv: Server, rev: String, +val: Value.Json, many: Bool) -> Turn:
  match many:
    case True{}:
      Turn{batch(srv, Json.items(val)), rev}
    case False{}:
      turn.msg(srv, rev, Rpc.classify(val))

# a decoded message, or text that was not JSON
def turn.parsed(srv: Server, +rev: String, meth: Maybe<&2, Value.Json>) -> Turn:
  match meth:
    case None{}:
      Turn{unparsed(), rev}
    case Some{+v}:
      turn.value(srv, rev, v, Bool.and(Json.is_arr(v), batches(rev)))

# what a server does with one message's text, read by revision `rev`, and
# the revision the stream's next message is read by
def turn(srv: Server, rev: String, text: String) -> Turn:
  turn.parsed(srv, rev, Json.parse(text))

# a turn's act
def turn.act(tn: Turn) -> Act:
  match tn:
    case Turn{act, rev}:
      act

# what a server does with one message's text, read by revision `rev`
def step(srv: Server, rev: String, text: String) -> Act:
  turn.act(turn(srv, rev, text))

# --- the reply to a tool call ---

def without.pair(hit: Bool, key: String, val: Value.Json, rest: Value.Json) -> Value.Json:
  match hit:
    case True{}:
      rest
    case False{}:
      Value.JPair{key, val, rest}

def without.bind(
  hit: Bool,
  src: String,
  num: U32,
  val: Value.Json,
  rest: Value.Json
) -> Value.Json:
  match hit:
    case True{}:
      rest
    case False{}:
      Value.JBind{src, num, val, rest}

# an object's members, less every one named `key`
def without.go(cells: Value.Json, +key: String) -> Value.Json:
  match cells:
    case Value.JPair{+k, v, r}:
      without.pair(Value.find.eq(k, key), k, v, without.go(r, key))
    case Value.JBind{+src, +num, v, r}:
      without.bind(Value.span.eq(src, num, key), src, num, v,
        without.go(r, key))
    case other:
      other

# an object less every member named `key`; any other value as it is
def without(val: Value.Json, key: String) -> Value.Json:
  match val:
    case Value.JObj{pairs}:
      Value.JObj{without.go(pairs, key)}
    case other:
      other

def shape.of(result: Value.Json, old: Bool) -> Value.Json:
  match old:
    case True{}:
      without(result, "structuredContent")
    case False{}:
      result

# a tool's result as revision `rev` reads it: 2025-03-26 has no
# structuredContent (2025-06-18/server/tools#structured-content), so it is
# left out; any later revision gets the result as the runner answered it
def shape(rev: String, result: Value.Json) -> Value.Json:
  shape.of(result, String.eq(rev, oldest()))

# the reply to a tool call under revision `rev`, once the runner answered:
# its tool result, shaped for the revision, or the protocol error it chose
# (server/tools#error-handling)
def ran(rev: String, id: Value.Json, out: Rpc.Out) -> Value.Json:
  match out:
    case Rpc.Ok{result}:
      Rpc.reply(id, Rpc.Ok{shape(rev, result)})
    case Rpc.Err{c, message}:
      Rpc.reply(id, Rpc.Err{c, message})

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
