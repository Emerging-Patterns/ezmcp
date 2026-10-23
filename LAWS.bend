# ezmcp: the laws. Each law carries the SPEC.md row it proves, or proves part
# of, on its own comment line. PROOF.bend fills them; `bend PROOF.bend` is
# the gate. Only the pure modules are imported: src/io.bend reaches
# ezhttp's socket effects, and no file that reaches them can print ALL
# PROOFS CHECK.
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import 0xa4d47e5f0f6044ac1a983d1b051fa47a/src/http.bend as Http
import ./src/rpc.bend as Rpc
import ./src/server.bend as Server
import ./src/web.bend as Web
import ./src/line.bend as Line
import ./src/sse.bend as Sse
import ./src/client.bend as Client

# --- the specification's own words ---

# the id a server's act sends back: a reply's id, a tool call's id; null
# for no reply
def sent.id(lead: Server.Act) -> Value.Json:
  match lead:
    case Server.Quiet{}:
      Json.null()
    case Server.Send{reply}:
      Json.get(reply, "id")
    case Server.Fault{reply}:
      Json.get(reply, "id")
    case Server.Run{id, name, args}:
      id

# whether a value has a member and not another
def has.only(+val: Value.Json, yes: String, no: String) -> Bool:
  Bool.and(Json.has(val, yes), Bool.not(Json.has(val, no)))

# whether bytes hold no newline
def clean.one(piece: List<&2, U32>) -> Bool:
  match piece:
    case []:
      True{}
    case +b <> t:
      Bool.and(Bool.not(Line.nl(b)), clean.one(t))

def line.ok.at(tail: List<&2, U32>, +byte: U32) -> Bool:
  match tail:
    case []:
      Line.nl(byte)
    case c <> u:
      Bool.and(Bool.not(Line.nl(byte)), line.ok.at(u, c))

# whether bytes are one line: no newline but the last byte, which is one
def line.ok(piece: List<&2, U32>) -> Bool:
  match piece:
    case []:
      False{}
    case +b <> t:
      line.ok.at(t, b)

def pieces.ok.at(rest: List<&2, List<&2, U32>>, piece: List<&2, U32>) -> Bool:
  match rest:
    case []:
      clean.one(piece)
    case q <> more:
      Bool.and(line.ok(piece), pieces.ok.at(more, q))

# whether pieces are lines, then a last piece with no newline
def pieces.ok(ps: List<&2, List<&2, U32>>) -> Bool:
  match ps:
    case []:
      False{}
    case p <> rest:
      pieces.ok.at(rest, p)

# whether every piece is a line
def lines.ok(ps: List<&2, List<&2, U32>>) -> Bool:
  match ps:
    case []:
      True{}
    case p <> rest:
      Bool.and(line.ok(p), lines.ok(rest))

# pieces' bytes, one after another
def flat(ps: List<&2, List<&2, U32>>) -> List<&2, U32>:
  match ps:
    case []:
      []
    case p <> rest:
      List.append(&2, U32, p, flat(rest))

# the bytes a cut came from: its lines, then its rest
def glue(cb: Line.Cut) -> List<&2, U32>:
  match cb:
    case Line.Cut{lines, rest}:
      List.append(&2, U32, flat(lines), rest)

# a cut's lines
def cut.lines(cb: Line.Cut) -> List<&2, List<&2, U32>>:
  match cb:
    case Line.Cut{lines, rest}:
      lines

# a cut's rest
def cut.rest(cb: Line.Cut) -> List<&2, U32>:
  match cb:
    case Line.Cut{lines, rest}:
      rest

# --- JSON-RPC messages (MCP-RPC) ---

# LAW: an object with jsonrpc "2.0", a method and a valid id is a request
# with that id, method and params
# MCP-RPC-1
law request_is_ask:
  for id: Value.Json
  for m: String
  for params: Value.Json
  for r: Bool
  for e: Bool
  {Rpc.decide(Rpc.Head{True{}, True{}, True{}, True{}, id, Some{m}, params, r,
    e}) == Rpc.Ask{id, m, params} : Rpc.Msg}

# LAW: every string is a valid id
# MCP-RPC-1
law id_string:
  for s: String
  {Rpc.id.ok(Value.JStr{s}) == True{} : Bool}

# LAW: a number is a valid id exactly when its text is an integer
# MCP-RPC-1
law id_number:
  for raw: String
  {Rpc.id.ok(Value.JNum{raw}) == Rpc.int.text(raw) : Bool}

# LAW: an integer's text may open with a minus, then digits
# MCP-RPC-1
law int_minus:
  for t: String
  {Rpc.int.text(SCon{'-', t}) == Rpc.digits(t) : Bool}

# LAW: any other integer's text is digits only
# MCP-RPC-1
law int_digits:
  for h: Char
  for t: String
  for e: {Char.is_eq(h, '-') == False{} : Bool}
  {Rpc.int.text(SCon{h, t}) == Rpc.digits(SCon{h, t}) : Bool}

# LAW: a value that is neither a string nor a number is no valid id: null,
# a boolean, an array, an object
# MCP-RPC-2
law id_other:
  for v: Value.Json
  for es: {Json.as_str(v) == None{} : Maybe<&2, String>}
  for en: {Json.as_num(v) == None{} : Maybe<&2, String>}
  {Rpc.id.ok(v) == False{} : Bool}

# LAW: a message with a method and an id that is not valid is an invalid
# request, answered with a null id
# MCP-RPC-2
law request_bad_id:
  for id: Value.Json
  for m: String
  for params: Value.Json
  for r: Bool
  for e: Bool
  {Rpc.decide(Rpc.Head{True{}, True{}, True{}, False{}, id, Some{m}, params,
    r, e})
    == Rpc.Junk{Json.null(), "Invalid Request: id must be a string or an integer"}
    : Rpc.Msg}

# LAW: a message with a method and no id is a notification
# MCP-RPC-3
law notification_is_tell:
  for ok: Bool
  for id: Value.Json
  for m: String
  for params: Value.Json
  for r: Bool
  for e: Bool
  {Rpc.decide(Rpc.Head{True{}, True{}, False{}, ok, id, Some{m}, params, r,
    e}) == Rpc.Tell{m, params} : Rpc.Msg}

# LAW: a notification gets nothing back
# MCP-RPC-3
law tell_is_quiet:
  for srv: Server.Server
  for m: String
  for params: Value.Json
  {Server.handle(srv, Rpc.Tell{m, params}) == Server.Quiet{} : Server.Act}

# LAW: a message with no method, a valid id and exactly one of result and
# error is a response
# MCP-RPC-4
law response_is_answer:
  for id: Value.Json
  for params: Value.Json
  for r: Bool
  for e: Bool
  for one: {Rpc.one(r, e) == True{} : Bool}
  {Rpc.decide(Rpc.Head{True{}, True{}, True{}, True{}, id, None{}, params, r,
    e}) == Rpc.Answer{id} : Rpc.Msg}

# LAW: a response gets nothing back
# MCP-RPC-4
law answer_is_quiet:
  for srv: Server.Server
  for id: Value.Json
  {Server.handle(srv, Rpc.Answer{id}) == Server.Quiet{} : Server.Act}

# LAW: a reply carries the id it was given
# MCP-RPC-5
law reply_id:
  for id: Value.Json
  for out: Rpc.Out
  {Json.get(Rpc.reply(id, out), "id") == id : Value.Json}

# LAW: whatever a request's method does, what the server sends back carries
# the request's id
# MCP-RPC-5
law answer_id:
  for id: Value.Json
  for s: Server.Step
  {sent.id(Server.answer(id, s)) == id : Value.Json}

# LAW: a tool's reply carries the call's id
# MCP-RPC-5
law ran_id:
  for id: Value.Json
  for result: Value.Json
  {Json.get(Server.ran(id, result), "id") == id : Value.Json}

# LAW: a successful reply has a result and no error
# MCP-RPC-6
law reply_ok_one:
  for id: Value.Json
  for result: Value.Json
  {has.only(Rpc.reply(id, Rpc.Ok{result}), "result", "error") == True{}
    : Bool}

# LAW: an error reply has an error and no result
# MCP-RPC-6
law reply_err_one:
  for id: Value.Json
  for c: Rpc.Code
  for message: String
  {has.only(Rpc.reply(id, Rpc.Err{c, message}), "error", "result") == True{}
    : Bool}

# LAW: an error's code is a number whose text is an integer
# MCP-RPC-7
law code_integer:
  for c: Rpc.Code
  {Rpc.int.text(Rpc.code.num(c)) == True{} : Bool}

# LAW: an error reply's error is its code and its message
# MCP-RPC-7
law reply_err_fields:
  for id: Value.Json
  for c: Rpc.Code
  for message: String
  {Json.get(Rpc.reply(id, Rpc.Err{c, message}), "error")
    == Json.obj([("code", Json.num(Rpc.code.num(c))),
      ("message", Json.str(message))]) : Value.Json}

# LAW: every reply says jsonrpc "2.0"
# MCP-RPC-8
law reply_v2:
  for id: Value.Json
  for out: Rpc.Out
  {Json.get(Rpc.reply(id, out), "jsonrpc") == Json.str("2.0") : Value.Json}

# LAW: every request says jsonrpc "2.0"
# MCP-RPC-8
law request_v2:
  for id: Value.Json
  for m: String
  for params: Value.Json
  {Json.get(Rpc.request(id, m, params), "jsonrpc") == Json.str("2.0")
    : Value.Json}

# LAW: every notification says jsonrpc "2.0"
# MCP-RPC-8
law notice_v2:
  for m: String
  for params: Value.Json
  {Json.get(Rpc.notice(m, params), "jsonrpc") == Json.str("2.0") : Value.Json}

# LAW: an object whose jsonrpc is not "2.0" is an invalid request
# MCP-RPC-8
law not_v2_junk:
  for has_id: Bool
  for ok: Bool
  for id: Value.Json
  for m: Maybe<&2, String>
  for params: Value.Json
  for r: Bool
  for e: Bool
  {Rpc.decide(Rpc.Head{True{}, False{}, has_id, ok, id, m, params, r, e})
    == Rpc.Junk{Rpc.head.id(has_id, ok, id),
      "Invalid Request: jsonrpc must be \"2.0\""} : Rpc.Msg}

# LAW: text that is not JSON is a parse error with a null id
# MCP-RPC-9
law parse_error:
  for srv: Server.Server
  for text: String
  for e: {Json.parse(text) == None{} : Maybe<&2, Value.Json>}
  {Server.step(srv, text)
    == Server.Fault{Rpc.reply(Json.null(),
      Rpc.Err{Rpc.ParseError{}, "Parse error"})} : Server.Act}

# LAW: a value that is not an object is an invalid request with a null id
# MCP-RPC-10
law not_object_junk:
  for v2: Bool
  for has_id: Bool
  for ok: Bool
  for id: Value.Json
  for m: Maybe<&2, String>
  for params: Value.Json
  for r: Bool
  for e: Bool
  {Rpc.decide(Rpc.Head{False{}, v2, has_id, ok, id, m, params, r, e})
    == Rpc.Junk{Json.null(), "Invalid Request: not a JSON-RPC object"}
    : Rpc.Msg}

# LAW: an array (a batch, which 2025-06-18 removed) is an invalid request
# MCP-RPC-10
law batch_junk:
  for items: List<&2, Value.Json>
  {Rpc.classify(Json.arr(items))
    == Rpc.Junk{Json.null(), "Invalid Request: not a JSON-RPC object"}
    : Rpc.Msg}

# LAW: a message with no method that is not a response is an invalid request
# MCP-RPC-10
law no_method_junk:
  for has_id: Bool
  for ok: Bool
  for id: Value.Json
  for params: Value.Json
  for r: Bool
  for e: Bool
  for none: {Bool.and(Bool.and(has_id, ok), Rpc.one(r, e)) == False{} : Bool}
  {Rpc.decide(Rpc.Head{True{}, True{}, has_id, ok, id, None{}, params, r, e})
    == Rpc.Junk{Rpc.head.id(has_id, ok, id), "Invalid Request: no method"}
    : Rpc.Msg}

# LAW: an invalid request is a fault with code -32600
# MCP-RPC-10
law junk_fault:
  for srv: Server.Server
  for id: Value.Json
  for why: String
  {Server.handle(srv, Rpc.Junk{id, why})
    == Server.Fault{Rpc.reply(id, Rpc.Err{Rpc.InvalidRequest{}, why})}
    : Server.Act}

# LAW: an invalid request's error carries its id only when it is valid
# MCP-RPC-10
law junk_id:
  for has_id: Bool
  for ok: Bool
  for id: Value.Json
  {Rpc.head.id(has_id, ok, id)
    == Bool.pick(Value.Json, Bool.and(has_id, ok), id, Json.null())
    : Value.Json}

# LAW: a request for a method the server does not have is method not found
# MCP-RPC-11
law method_not_found:
  for srv: Server.Server
  for m: String
  for params: Value.Json
  for e: {Server.method.of(m) == Server.Other{} : Server.Method}
  {Server.dispatch(srv, m, params)
    == Server.Now{Rpc.Err{Rpc.MethodNotFound{}, "Method not found: " ++ m}}
    : Server.Step}

# LAW: a request is answered by its method's step
# MCP-RPC-11
law ask_dispatch:
  for srv: Server.Server
  for id: Value.Json
  for m: String
  for params: Value.Json
  {Server.handle(srv, Rpc.Ask{id, m, params})
    == Server.answer(id, Server.dispatch(srv, m, params)) : Server.Act}

# --- lifecycle (MCP-LIFE) ---

# LAW: initialize is answered with the server's initialize result
# MCP-LIFE-1
law initialize_dispatch:
  for srv: Server.Server
  for params: Value.Json
  {Server.dispatch(srv, "initialize", params)
    == Server.Now{Rpc.Ok{Server.init(srv, params)}} : Server.Step}

# LAW: the result names the server's name and version
# MCP-LIFE-1
law init_info:
  for name: String
  for version: String
  for +instructions: String
  for tools: List<&2, Server.Tool>
  for params: Value.Json
  {Json.get(Server.init(Server.Server{name, version, instructions, tools},
    params), "serverInfo")
    == Json.obj([("name", Json.str(name)), ("version", Json.str(version))])
    : Value.Json}

# LAW: the result carries instructions when the server has some
# MCP-LIFE-1
law init_instructions:
  for name: String
  for version: String
  for +instructions: String
  for tools: List<&2, Server.Tool>
  for params: Value.Json
  for e: {String.is_empty(instructions) == False{} : Bool}
  {Json.get(Server.init(Server.Server{name, version, instructions, tools},
    params), "instructions") == Json.str(instructions) : Value.Json}

# LAW: and none when it has none
# MCP-LIFE-1
law init_no_instructions:
  for name: String
  for version: String
  for +instructions: String
  for tools: List<&2, Server.Tool>
  for params: Value.Json
  for e: {String.is_empty(instructions) == True{} : Bool}
  {Json.has(Server.init(Server.Server{name, version, instructions, tools},
    params), "instructions") == False{} : Bool}

# LAW: the result's protocolVersion is the negotiated one
# MCP-LIFE-2
law init_version:
  for srv: Server.Server
  for params: Value.Json
  {Json.get(Server.init(srv, params), "protocolVersion")
    == Json.str(Server.negotiate(Json.as_str(Json.get(params,
      "protocolVersion")))) : Value.Json}

# LAW: a supported revision is echoed
# MCP-LIFE-2
law negotiate_echo:
  for v: String
  for e: {Server.supported(v) == True{} : Bool}
  {Server.negotiate(Some{v}) == v : String}

# LAW: any other request gets the latest revision
# MCP-LIFE-2
law negotiate_latest:
  for v: String
  for e: {Server.supported(v) == False{} : Bool}
  {Server.negotiate(Some{v}) == Server.latest() : String}

# LAW: whatever a client asks for, the answer is a revision ezmcp speaks
# MCP-LIFE-2
law negotiate_supported:
  for asked: Maybe<&2, String>
  {Server.supported(Server.negotiate(asked)) == True{} : Bool}

# LAW: the result's capabilities are the tool table's
# MCP-LIFE-3
law init_caps:
  for name: String
  for version: String
  for +instructions: String
  for tools: List<&2, Server.Tool>
  for params: Value.Json
  {Json.get(Server.init(Server.Server{name, version, instructions, tools},
    params), "capabilities") == Server.capabilities(tools) : Value.Json}

# LAW: a server with tools declares the tools capability, listChanged false
# MCP-LIFE-3
law caps_tools:
  for t: Server.Tool
  for rest: List<&2, Server.Tool>
  {Json.get(Server.capabilities(t <> rest), "tools")
    == Json.obj([("listChanged", Json.bool(False{}))]) : Value.Json}

# LAW: a server with no tools declares no capability
# MCP-LIFE-3
law caps_none:
  for tools: List<&2, Server.Tool>
  for e: {List.is_empty(&2, Server.Tool, tools) == True{} : Bool}
  {Server.capabilities(tools) == Json.obj([]) : Value.Json}

# LAW: ping is answered with an empty result
# MCP-LIFE-4
law ping_empty:
  for srv: Server.Server
  for params: Value.Json
  {Server.dispatch(srv, "ping", params) == Server.Now{Rpc.Ok{Json.obj([])}}
    : Server.Step}

# --- tools (MCP-TOOL) ---

# LAW: tools/list is answered with the server's list
# MCP-TOOL-1
law list_dispatch:
  for srv: Server.Server
  for params: Value.Json
  {Server.dispatch(srv, "tools/list", params)
    == Server.Now{Rpc.Ok{Server.list(srv)}} : Server.Step}

# LAW: the list holds every tool of the table, in order
# MCP-TOOL-1
law list_items:
  for name: String
  for version: String
  for instructions: String
  for tools: List<&2, Server.Tool>
  {Json.items(Json.get(Server.list(Server.Server{name, version, instructions,
    tools}), "tools")) == Server.tool.all(tools) : List<&2, Value.Json>}

# LAW: the list shows each tool by its own description
# MCP-TOOL-1
law list_each:
  for t: Server.Tool
  for rest: List<&2, Server.Tool>
  {Server.tool.all(t <> rest) == Server.tool.json(t) <> Server.tool.all(rest)
    : List<&2, Value.Json>}

# LAW: a tool shows its name, description and input schema
# MCP-TOOL-1
law tool_fields:
  for name: String
  for description: String
  for input: Value.Json
  {Server.tool.json(Server.Tool{name, description, input})
    == Json.obj([("name", Json.str(name)),
      ("description", Json.str(description)), ("inputSchema", input)])
    : Value.Json}

# LAW: the list is one page: it has no nextCursor
# MCP-TOOL-1
law list_one_page:
  for srv: Server.Server
  {Json.has(Server.list(srv), "nextCursor") == False{} : Bool}

# LAW: tools/call is the server's call step
# MCP-TOOL-2
law call_dispatch:
  for srv: Server.Server
  for params: Value.Json
  {Server.dispatch(srv, "tools/call", params) == Server.call(srv, params)
    : Server.Step}

# LAW: a tool the table names is known
# MCP-TOOL-2
law known_named:
  for name: String
  for description: String
  for input: Value.Json
  for rest: List<&2, Server.Tool>
  {Server.known(Server.Tool{name, description, input} <> rest, name)
    == True{} : Bool}

# LAW: a call of a known tool with object arguments runs it on them
# MCP-TOOL-2
law call_runs:
  for name: String
  for params: Value.Json
  for has: {Json.has(params, "arguments") == True{} : Bool}
  for obj: {Json.is_obj(Json.get(params, "arguments")) == True{} : Bool}
  {Server.call.known(name, params, True{})
    == Server.Call{name, Json.get(params, "arguments")} : Server.Step}

# LAW: a call of a known tool with no arguments runs it on {}
# MCP-TOOL-2
law call_no_args:
  for name: String
  for params: Value.Json
  for has: {Json.has(params, "arguments") == False{} : Bool}
  {Server.call.known(name, params, True{}) == Server.Call{name, Json.obj([])}
    : Server.Step}

# LAW: a call names its tool by params.name
# MCP-TOOL-2
law call_named:
  for name: String
  for description: String
  for version: String
  for instructions: String
  for tools: List<&2, Server.Tool>
  for params: Value.Json
  for n: String
  for e: {Json.as_str(Json.get(params, "name")) == Some{n} : Maybe<&2, String>}
  {Server.call(Server.Server{name, version, instructions, tools}, params)
    == Server.call.known(n, params, Server.known(tools, n)) : Server.Step}

# LAW: a call to run is a Run with the request's id
# MCP-TOOL-2
law call_is_run:
  for id: Value.Json
  for name: String
  for args: Value.Json
  {Server.answer(id, Server.Call{name, args}) == Server.Run{id, name, args}
    : Server.Act}

# LAW: a call of an unknown tool is invalid params
# MCP-TOOL-3
law call_unknown:
  for name: String
  for params: Value.Json
  {Server.call.known(name, params, False{})
    == Server.Now{Rpc.Err{Rpc.InvalidParams{}, "Unknown tool: " ++ name}}
    : Server.Step}

# LAW: no tool is known to an empty table
# MCP-TOOL-3
law known_none:
  for name: String
  {Server.known([], name) == False{} : Bool}

# LAW: a call whose name is not a string is invalid params
# MCP-TOOL-4
law call_no_name:
  for srv: Server.Server
  for params: Value.Json
  for e: {Json.as_str(Json.get(params, "name")) == None{} : Maybe<&2, String>}
  {Server.call(srv, params)
    == Server.Now{Rpc.Err{Rpc.InvalidParams{},
      "tools/call: params.name must be a string"}} : Server.Step}

# LAW: a call whose arguments are not an object is invalid params
# MCP-TOOL-4
law call_bad_args:
  for name: String
  for params: Value.Json
  for has: {Json.has(params, "arguments") == True{} : Bool}
  for obj: {Json.is_obj(Json.get(params, "arguments")) == False{} : Bool}
  {Server.call.known(name, params, True{})
    == Server.Now{Rpc.Err{Rpc.InvalidParams{},
      "tools/call: arguments must be an object"}} : Server.Step}

# LAW: a tool result's isError is the flag it was given
# MCP-TOOL-5
law result_flag:
  for blocks: List<&2, Value.Json>
  for bad: Bool
  {Json.get(Server.result(blocks, bad), "isError") == Json.bool(bad)
    : Value.Json}

# LAW: a tool result's content is its blocks, in order
# MCP-TOOL-5
law result_content:
  for blocks: List<&2, Value.Json>
  for bad: Bool
  {Json.items(Json.get(Server.result(blocks, bad), "content")) == blocks
    : List<&2, Value.Json>}

# LAW: a text block is a TextContent
# MCP-TOOL-5
law text_block:
  for s: String
  {Server.text(s) == Json.obj([("type", Json.str("text")), ("text", Json.str(s))])
    : Value.Json}

# LAW: the reply to a tool call is a result holding the tool's result
# MCP-TOOL-5
law ran_result:
  for id: Value.Json
  for result: Value.Json
  {Json.get(Server.ran(id, result), "result") == result : Value.Json}

# LAW: structured content is the value itself
# MCP-TOOL-6
law structured_value:
  for v: Value.Json
  for bad: Bool
  {Json.get(Server.structured(v, bad), "structuredContent") == v : Value.Json}

# LAW: and its content is one text block of the value's JSON text
# MCP-TOOL-6
law structured_text:
  for v: Value.Json
  for bad: Bool
  {Json.items(Json.get(Server.structured(v, bad), "content"))
    == [Server.text(Json.print(v))] : List<&2, Value.Json>}

# --- streamable HTTP (MCP-HTTP) ---

# LAW: a request's HTTP decision is made from its path, Origin, method,
# MCP-Protocol-Version and body
# MCP-HTTP-1
law web_parts:
  for srv: Server.Server
  for path: String
  for origins: List<&2, String>
  for +m: String
  for +target: String
  for +headers: List<&2, Http.Header>
  for body: String
  {Web.decide(srv, path, origins, Http.Request{m, target, headers, body})
    == Web.route(srv, String.eq(Web.path.of(target), path),
      Web.origin.ok(origins, Http.headers.find(headers, "Origin")),
      String.eq(m, "POST"),
      Web.version.ok(Http.headers.find(headers, "MCP-Protocol-Version")), body)
    : Web.Web}

# LAW: a POST to the endpoint that passes the checks is the server's step
# MCP-HTTP-1
law web_post:
  for srv: Server.Server
  for body: String
  {Web.route(srv, True{}, True{}, True{}, True{}, body)
    == Web.act(Server.step(srv, body)) : Web.Web}

# LAW: a request's reply is 200 with one JSON body
# MCP-HTTP-1
law web_send:
  for reply: Value.Json
  {Web.act(Server.Send{reply})
    == Web.Now{200, [Http.H{"Content-Type", "application/json"}],
      Json.print(reply)} : Web.Web}

# LAW: a tool call's reply is 200 with one JSON body
# MCP-HTTP-1
law web_ran:
  for id: Value.Json
  for result: Value.Json
  {Web.ran(id, result)
    == Web.Now{200, [Http.H{"Content-Type", "application/json"}],
      Json.print(Server.ran(id, result))} : Web.Web}

# LAW: a tool call is run before the reply
# MCP-HTTP-1
law web_run:
  for id: Value.Json
  for name: String
  for args: Value.Json
  {Web.act(Server.Run{id, name, args}) == Web.Later{id, name, args} : Web.Web}

# LAW: a notification is accepted: 202, no body
# MCP-HTTP-2
law web_tell:
  for srv: Server.Server
  for m: String
  for params: Value.Json
  {Web.act(Server.handle(srv, Rpc.Tell{m, params})) == Web.Now{202, [], ""}
    : Web.Web}

# LAW: a response is accepted: 202, no body
# MCP-HTTP-2
law web_answer:
  for srv: Server.Server
  for id: Value.Json
  {Web.act(Server.handle(srv, Rpc.Answer{id})) == Web.Now{202, [], ""}
    : Web.Web}

# LAW: a message the server cannot accept is 400, with its JSON-RPC error
# MCP-HTTP-3
law web_fault:
  for reply: Value.Json
  {Web.act(Server.Fault{reply})
    == Web.Now{400, [Http.H{"Content-Type", "application/json"}],
      Json.print(reply)} : Web.Web}

# LAW: an HTTP request that does not parse is 400
# MCP-HTTP-3
law web_bad:
  for srv: Server.Server
  for path: String
  for origins: List<&2, String>
  for why: String
  {Web.decide(srv, path, origins, Http.Bad{why}) == Web.text(400, why)
    : Web.Web}

# LAW: any method but POST is 405, with Allow: POST
# MCP-HTTP-4
law web_not_post:
  for srv: Server.Server
  for version: Bool
  for body: String
  {Web.route(srv, True{}, True{}, False{}, version, body)
    == Web.Now{405, [Http.H{"Allow", "POST"}], ""} : Web.Web}

# LAW: a request whose Origin is not allowed is 403, whatever its method
# MCP-HTTP-5
law web_origin:
  for srv: Server.Server
  for is_post: Bool
  for version: Bool
  for body: String
  {Web.route(srv, True{}, False{}, is_post, version, body)
    == Web.text(403, "Forbidden: Origin not allowed") : Web.Web}

# LAW: a request with no Origin passes
# MCP-HTTP-5
law origin_absent:
  for origins: List<&2, String>
  {Web.origin.ok(origins, "") == True{} : Bool}

# LAW: a page on this machine passes
# MCP-HTTP-5
law origin_loopback:
  for origins: List<&2, String>
  for origin: String
  for e: {Web.loopback(origin) == True{} : Bool}
  {Web.origin.ok(origins, origin) == True{} : Bool}

# LAW: http://localhost with a port is a page on this machine
# MCP-HTTP-5
law loopback_localhost:
  for port: String
  {Web.loopback("http://localhost:" ++ port) == Rpc.digits(port) : Bool}

# LAW: http://127.0.0.1 with a port is a page on this machine
# MCP-HTTP-5
law loopback_ipv4:
  for port: String
  {Web.loopback("http://127.0.0.1:" ++ port) == Rpc.digits(port) : Bool}

# LAW: any other Origin passes exactly when the server lists it
# MCP-HTTP-5
law origin_other:
  for origins: List<&2, String>
  for origin: String
  for ee: {String.is_empty(origin) == False{} : Bool}
  for el: {Web.loopback(origin) == False{} : Bool}
  {Web.origin.ok(origins, origin) == Web.origin.listed(origins, origin) : Bool}

# LAW: a listed Origin is listed
# MCP-HTTP-5
law origin_listed:
  for origin: String
  for rest: List<&2, String>
  {Web.origin.listed(origin <> rest, origin) == True{} : Bool}

# LAW: an empty list lists no Origin
# MCP-HTTP-5
law origin_none:
  for origin: String
  {Web.origin.listed([], origin) == False{} : Bool}

# LAW: an Origin the list's first entry is not is listed only if the rest
# lists it
# MCP-HTTP-5
law origin_unlisted:
  for listed: String
  for rest: List<&2, String>
  for origin: String
  for e: {String.eq(listed, origin) == False{} : Bool}
  {Web.origin.listed(listed <> rest, origin) == Web.origin.listed(rest, origin)
    : Bool}

# LAW: an unsupported MCP-Protocol-Version is 400
# MCP-HTTP-6
law web_version:
  for srv: Server.Server
  for body: String
  {Web.route(srv, True{}, True{}, True{}, False{}, body)
    == Web.text(400, "Bad Request: unsupported MCP-Protocol-Version")
    : Web.Web}

# LAW: a version header is acceptable when absent or supported, and only then
# MCP-HTTP-6
law version_ok:
  for v: String
  {Web.version.ok(v) == Bool.or(String.is_empty(v), Server.supported(v)) : Bool}

# LAW: a request to another path is 404
# MCP-HTTP-7
law web_path:
  for srv: Server.Server
  for allowed: Bool
  for is_post: Bool
  for version: Bool
  for body: String
  {Web.route(srv, False{}, allowed, is_post, version, body)
    == Web.text(404, "Not Found") : Web.Web}

# --- stdio (MCP-STDIO) ---

# LAW: the pieces split after newlines are the bytes, in order
# MCP-STDIO-1
law split_flat:
  for +bs: List<&2, U32>
  {flat(Line.split(bs)) == bs : List<&2, U32>}

# LAW: the pieces are lines, then a last piece with no newline
# MCP-STDIO-1
law split_pieces:
  for +bs: List<&2, U32>
  {pieces.ok(Line.split(bs)) == True{} : Bool}

# LAW: a cut's lines and rest are the buffer, in order
# MCP-STDIO-1
law cut_glue:
  for +bs: List<&2, U32>
  {glue(Line.cut(bs)) == bs : List<&2, U32>}

# LAW: every line a cut hands on is one line: a newline at its end and none
# before it
# MCP-STDIO-1
law cut_lines:
  for +bs: List<&2, U32>
  {lines.ok(cut.lines(Line.cut(bs))) == True{} : Bool}

# LAW: what a cut keeps for the next read holds no newline
# MCP-STDIO-1
law cut_rest:
  for +bs: List<&2, U32>
  {clean.one(cut.rest(Line.cut(bs))) == True{} : Bool}

# LAW: an ASCII byte is its own char
# MCP-STDIO-2
law utf8_one:
  for b: U32
  for t: List<&2, U32>
  for go: List<&2, U32> -> String
  for e: {U32.is_lt(b, 128) == True{} : Bool}
  {Line.decode.step(b <> t, go) == SCon{Chr{b}, go(t)} : String}

# LAW: a two-byte lead and a continuation byte are one char
# MCP-STDIO-2
law utf8_two:
  for a: U32
  for b: U32
  for t: List<&2, U32>
  for go: List<&2, U32> -> String
  for w: {Line.width(a) == Line.W2{} : Line.Width}
  for c: {Line.cont(b) == True{} : Bool}
  {Line.decode.step(a <> b <> t, go) == SCon{Chr{Line.two(a, b)}, go(t)}
    : String}

# LAW: a three-byte lead and two continuation bytes are one char
# MCP-STDIO-2
law utf8_three:
  for a: U32
  for b: U32
  for c: U32
  for t: List<&2, U32>
  for go: List<&2, U32> -> String
  for w: {Line.width(a) == Line.W3{} : Line.Width}
  for k: {Bool.and(Line.cont(b), Line.cont(c)) == True{} : Bool}
  {Line.decode.step(a <> b <> c <> t, go)
    == SCon{Chr{Line.three(a, b, c)}, go(t)} : String}

# LAW: a four-byte lead and three continuation bytes are one char
# MCP-STDIO-2
law utf8_four:
  for a: U32
  for b: U32
  for c: U32
  for d: U32
  for t: List<&2, U32>
  for go: List<&2, U32> -> String
  for w: {Line.width(a) == Line.W4{} : Line.Width}
  for k: {Bool.and(Line.cont(b), Bool.and(Line.cont(c), Line.cont(d))) == True{}
    : Bool}
  {Line.decode.step(a <> b <> c <> d <> t, go)
    == SCon{Chr{Line.four(a, b, c, d)}, go(t)} : String}

# LAW: a byte that starts no sequence is U+FFFD, and decoding goes on after it
# MCP-STDIO-2
law utf8_bad_lead:
  for a: U32
  for t: List<&2, U32>
  for go: List<&2, U32> -> String
  for w: {Line.width(a) == Line.W0{} : Line.Width}
  {Line.decode.step(a <> t, go) == SCon{Line.bad(), go(t)} : String}

# LAW: a lead whose continuation byte is bad is U+FFFD, and decoding goes on
# at that byte
# MCP-STDIO-2
law utf8_bad_cont:
  for a: U32
  for b: U32
  for t: List<&2, U32>
  for go: List<&2, U32> -> String
  for w: {Line.width(a) == Line.W2{} : Line.Width}
  for c: {Line.cont(b) == False{} : Bool}
  {Line.decode.step(a <> b <> t, go) == SCon{Line.bad(), go(b <> t)} : String}

# LAW: a blank line is no message: nothing is written
# MCP-STDIO-3
law line_blank:
  for srv: Server.Server
  for text: String
  for e: {String.is_empty(String.trim(text)) == True{} : Bool}
  {Line.line.text(srv, text) == Server.Quiet{} : Server.Act}

# LAW: any other line is the server's step on its text
# MCP-STDIO-3
law line_message:
  for srv: Server.Server
  for text: String
  for e: {String.is_empty(String.trim(text)) == False{} : Bool}
  {Line.line.text(srv, text) == Server.step(srv, text) : Server.Act}

# LAW: a message on stdout is its JSON text and one newline
# MCP-STDIO-4
law frame_line:
  for v: Value.Json
  {Line.frame(v) == Json.print(v) ++ "\n" : String}

# --- client (MCP-CLIENT) ---

# LAW: a request carries its id
# MCP-CLIENT-1
law request_id:
  for id: Value.Json
  for m: String
  for params: Value.Json
  {Json.get(Rpc.request(id, m, params), "id") == id : Value.Json}

# LAW: a notification carries no id
# MCP-CLIENT-1
law notice_no_id:
  for m: String
  for params: Value.Json
  {Json.has(Rpc.notice(m, params), "id") == False{} : Bool}

# LAW: a tools/call request names the tool and passes the arguments
# MCP-CLIENT-1
law call_request:
  for id: Value.Json
  for name: String
  for args: Value.Json
  {Client.call(id, name, args) == Rpc.request(id, "tools/call",
    Json.obj([("name", Json.str(name)), ("arguments", args)])) : Value.Json}

# LAW: initialize sends the latest revision, capabilities and clientInfo
# MCP-CLIENT-2
law initialize_params:
  for id: Value.Json
  for name: String
  for version: String
  {Json.get(Client.initialize(id, name, version), "params")
    == Json.obj([("protocolVersion", Json.str(Server.latest())),
      ("capabilities", Json.obj([])),
      ("clientInfo", Json.obj([("name", Json.str(name)),
        ("version", Json.str(version))]))]) : Value.Json}

# LAW: before initialize, a POST accepts JSON and event streams
# MCP-CLIENT-3
law headers_first:
  for v: String
  for e: {String.is_empty(v) == True{} : Bool}
  {Client.headers(v)
    == [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"}]
    : List<&2, Http.Header>}

# LAW: after it, a POST also names the negotiated revision
# MCP-CLIENT-3
law headers_version:
  for v: String
  for e: {String.is_empty(v) == False{} : Bool}
  {Client.headers(v)
    == [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"},
      Http.H{"MCP-Protocol-Version", v}] : List<&2, Http.Header>}

# LAW: a 200 reply is read as an event stream or as JSON by its type
# MCP-CLIENT-4
law took_ok:
  for ctype: String
  for text: String
  for status: U32
  {Client.took.ok(ctype, text, True{}, status)
    == Rpc.read(Client.body(Client.is.sse(ctype), text)) : Rpc.Reply}

# LAW: an event stream's JSON text is its last data
# MCP-CLIENT-4
law body_sse:
  for text: String
  {Client.body(True{}, text) == Sse.last(text) : String}

# LAW: any other body is the JSON text
# MCP-CLIENT-4
law body_json:
  for text: String
  {Client.body(False{}, text) == text : String}

# LAW: a data line adds its value to the event, less one space
# MCP-CLIENT-4
law sse_data:
  for cur: Maybe<&2, String>
  for last: String
  for x: String
  {Sse.line(Sse.Sse{cur, last}, "data: " ++ x)
    == Sse.Sse{Sse.more(cur, x), last} : Sse.Sse}

# LAW: a blank line ends an event, whose data, if any, is the latest
# MCP-CLIENT-4
law sse_end:
  for d: String
  for last: String
  {Sse.line(Sse.Sse{Some{d}, last}, "") == Sse.Sse{None{}, d} : Sse.Sse}

# LAW: an event's data lines are joined by newlines
# MCP-CLIENT-4
law sse_more:
  for d: String
  for x: String
  {Sse.more(Some{d}, x) == Some{d ++ "\n" ++ x} : Maybe<&2, String>}

# LAW: a reply with a result is read as that result
# MCP-CLIENT-5
law read_got:
  for id: Value.Json
  for result: Value.Json
  for c: Maybe<&2, String>
  for m: Maybe<&2, String>
  {Rpc.back.decide(Rpc.Back{True{}, id, True{}, result, False{}, c, m})
    == Rpc.Got{id, result} : Rpc.Reply}

# LAW: a reply with an error is read as its code and message
# MCP-CLIENT-5
law read_refused:
  for id: Value.Json
  for result: Value.Json
  for c: String
  for m: String
  {Rpc.back.decide(Rpc.Back{True{}, id, False{}, result, True{}, Some{c},
    Some{m}}) == Rpc.Refused{id, c, m} : Rpc.Reply}

# LAW: a reply with both or neither is unread
# MCP-CLIENT-5
law read_both:
  for id: Value.Json
  for result: Value.Json
  for b: Bool
  for c: Maybe<&2, String>
  for m: Maybe<&2, String>
  {Rpc.back.decide(Rpc.Back{True{}, id, b, result, b, c, m})
    == Rpc.Unread{"a reply must hold exactly one of result and error"}
    : Rpc.Reply}

# LAW: a reply that is not JSON-RPC 2.0 is unread
# MCP-CLIENT-5
law read_not_v2:
  for id: Value.Json
  for r: Bool
  for result: Value.Json
  for e: Bool
  for c: Maybe<&2, String>
  for m: Maybe<&2, String>
  {Rpc.back.decide(Rpc.Back{False{}, id, r, result, e, c, m})
    == Rpc.Unread{"not a JSON-RPC 2.0 reply"} : Rpc.Reply}

# LAW: a reply that is not JSON is unread
# MCP-CLIENT-5
law read_not_json:
  for text: String
  for e: {Json.parse(text) == None{} : Maybe<&2, Value.Json>}
  {Rpc.read(text) == Rpc.Unread{"the reply is not JSON"} : Rpc.Reply}

# LAW: any status but 200 is unread, with the status and the body
# MCP-CLIENT-5
law took_status:
  for ctype: String
  for text: String
  for status: U32
  {Client.took.ok(ctype, text, False{}, status)
    == Rpc.Unread{"HTTP " ++ U32.show(status) ++ ": " ++ text} : Rpc.Reply}
