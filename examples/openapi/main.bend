# examples/openapi: an OpenAPI document as an MCP server. The document is
# read at run time (here, parsed from the text below), so the server rides
# in the context and is served with `http.serve_from`. A tool call is
# checked against its input schema, refused with -32602 when it does not
# fit, and answered with the request it stands for; a real server sends
# that request to the API with ezhttp and answers what comes back.
#
#   openapi list                 the tools/list result
#   openapi call NAME ARGS       the request a call stands for
#   openapi http PORT N          POST /mcp on 127.0.0.1:PORT, for N
#                                connections
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import 0xedb2120a04a47dc18c3a756ec7c62750/src/http.bend as Http
import ../../main.bend as Mcp
import ../../src/server.bend as Server
import ../../src/rpc.bend as Rpc
import ../../src/openapi.bend as Openapi

# a small API: a path parameter, a query array, a header, a JSON body by
# reference, an operation with no operationId
def doc.text() -> String:
  "{\"openapi\":\"3.1.0\",\"info\":{\"title\":\"pets\",\"version\":\"1.0.0\"},\"paths\":{\"/pets/{pet_id}\":{\"parameters\":[{\"name\":\"pet_id\",\"in\":\"path\",\"required\":true,\"schema\":{\"type\":\"integer\"}}],\"get\":{\"operationId\":\"get_pet\",\"summary\":\"One pet\",\"parameters\":[{\"name\":\"fields\",\"in\":\"query\",\"schema\":{\"type\":\"array\",\"items\":{\"type\":\"string\"}}},{\"name\":\"X-Trace\",\"in\":\"header\",\"schema\":{\"type\":\"string\"}}]},\"put\":{\"operationId\":\"pets.update\",\"description\":\"Update a pet\",\"requestBody\":{\"required\":true,\"content\":{\"application/json\":{\"schema\":{\"$ref\":\"#/components/schemas/Pet\"}}}}}},\"/pets\":{\"post\":{\"requestBody\":{\"content\":{\"text/plain\":{}}}}}},\"components\":{\"schemas\":{\"Pet\":{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\",\"nullable\":true},\"age\":{\"type\":\"integer\",\"example\":3}},\"required\":[\"name\"]}}}}"

# each operation's tool
def tools(ops: List<&2, Openapi.Op>) -> List<&2, Server.Tool>:  # noqa: L001 example program, no law's subject
  match ops:
    case []:
      []
    case one <> rest:
      Openapi.tool(one) <> tools(rest)

# the server and its operations, as the runner is given them
type Api is Data:  # noqa: L001 example program, no law's subject
  Api{srv: Server.Server, ops: List<&2, Openapi.Op>}

def api.of(+doc: Value.Json) -> Api:
  +ops = Openapi.ops(doc)
  Api{Mcp.server("pets", Openapi.str.at(Json.get(doc, "info"), "version"), "",
    tools(ops)), ops}

# the server and operations of the document above
def api() -> Api:  # noqa: L001 example program, no law's subject
  api.of(Maybe.default(&2, Value.Json, Json.parse(doc.text()), Json.null()))

def api.srv(got: Api) -> Server.Server:
  match got:
    case Api{srv, ops}:
      srv

# the fields as a request head writes them, one to a line
def headers(hs: List<&2, Http.Header>) -> String:  # noqa: L001 example program, no law's subject
  match hs:
    case []:
      ""
    case Http.H{name, value} <> rest:
      "\n" ++ name ++ ": " ++ value ++ headers(rest)

# the body after a blank line, if there is one
def body(got: Maybe<&2, String>) -> String:  # noqa: L001 example program, no law's subject
  match got:
    case None{}:
      ""
    case Some{text}:
      "\n\n" ++ text

# a request as HTTP/1.1 writes its head: the request line, the fields, the
# body
def shown(sent: Openapi.Call) -> String:  # noqa: L001 example program, no law's subject
  match sent:
    case Openapi.Send{method, target, hs, got}:
      method ++ " " ++ target ++ headers(hs) ++ body(got)
    case Openapi.Unfilled{path}:
      "unfilled: " ++ path

# this operation when it is the one, else what the rest have
def found(  # noqa: L001 example program, no law's subject
  hit: Bool,
  +one: Openapi.Op,
  rest: Maybe<&2, Openapi.Op>
) -> Maybe<&2, Openapi.Op>:
  match hit:
    case True{}:
      Some{one}
    case False{}:
      rest

# the operation of this name, if there is one
def find(  # noqa: L001 example program, no law's subject
  ops: List<&2, Openapi.Op>,
  +name: String
) -> Maybe<&2, Openapi.Op>:
  match ops:
    case []:
      None{}
    case +one <> rest:
      found(String.eq(Openapi.name(one), name), one, find(rest, name))

# a refusal when the arguments do not fit, else the request
def checked(  # noqa: L001 example program, no law's subject
  +one: Openapi.Op,
  +args: Value.Json,
  why: Maybe<&2, String>
) -> Rpc.Out:
  match why:
    case Some{text}:
      Mcp.refuse.params(text)
    case None{}:
      Mcp.ok(Mcp.result.text(shown(Openapi.call(one, args))))

# the answer to a call of this operation, or of none
def answer(+args: Value.Json, got: Maybe<&2, Openapi.Op>) -> Rpc.Out:  # noqa: L001 example program, no law's subject
  match got:
    case None{}:
      Mcp.refuse.params("no such operation")
    case Some{+one}:
      checked(one, args, Openapi.check(one, args))

# a tool call: the request it stands for, or a refusal
def run(got: Api, +name: String, +args: Value.Json) -> IO(Rpc.Out):  # noqa: L001 example program, no law's subject
  match got:
    case Api{srv, ops}:
      IO.pure(Rpc.Out, answer(args, find(ops, name)))

# print the reply to one call
def call(+name: String, text: String) -> IO(Unit):  # noqa: L001 example program, no law's subject
  IO.bind(Rpc.Out, Unit, run(api(), name, Maybe.default(&2, Value.Json,
    Json.parse(text), Json.obj([]))),
    out => IO.print(Json.print(Server.ran("2025-06-18", Json.num("1"), out))))

# the mode the arguments name
@unsafe def mode(args: List<String>) -> IO(Unit):  # noqa: L001 example program, no law's subject
  match args:
    case _prog <> "list" <> _more:
      IO.print(Json.print(Server.list(api.srv(api()))))
    case _prog <> "call" <> name <> text <> _more:
      call(name, text)
    case _prog <> "http" <> port <> count <> _more:
      Mcp.http.serve_from(~Api, ~api.srv, ~(c => n => a => run(c, n, a)), ~"/mcp",
        ~[], api(), "127.0.0.1",
        Maybe.default(&2, U32, U32.read(port), 8000),
        Maybe.default(&2, U32, U32.read(count), 1), 0)
    case other:
      IO.print_err("usage: openapi list | openapi call NAME ARGS | openapi http PORT N")

@unsafe def main() -> IO(Unit):  # noqa: L001 example program, no law's subject
  IO.bind(List<String>, Unit, IO.args(), mode)
