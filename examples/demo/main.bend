# examples/demo: an MCP server with two tools, over stdio or streamable HTTP.
#
#   demo stdio [PREFIX]          newline-delimited JSON-RPC on stdin and
#                                stdout
#   demo http PORT [N [PREFIX]]  POST /mcp on 127.0.0.1:PORT, for N
#                                connections (forever when N is absent)
#
# The server runs with a context read at run time, PREFIX (empty when
# absent): echo answers PREFIX and its text, and refuses a text that is not a string with
# -32602 (a protocol error: the call does not match the schema); add answers
# the sum of two integers as structured content, or a tool error when they
# are not integers, which the model can correct.
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../../main.bend as Mcp
import ../../src/server.bend as Server
import ../../src/rpc.bend as Rpc

def schema.echo() -> Value.Json:
  Json.obj([("type", Json.str("object")),
    ("properties", Json.obj([("text", Json.obj([("type", Json.str("string"))]))])),
    ("required", Json.arr([Json.str("text")]))])

def schema.add() -> Value.Json:
  Json.obj([("type", Json.str("object")),
    ("properties", Json.obj([
      ("a", Json.obj([("type", Json.str("integer"))])),
      ("b", Json.obj([("type", Json.str("integer"))]))])),
    ("required", Json.arr([Json.str("a"), Json.str("b")]))])

# the demo server: two tools
def srv() -> Server.Server:
  Mcp.server("ezmcp-demo", "0.1.0", "Two small tools: echo and add.", [
    Mcp.tool("echo", "Answer the text back", schema.echo()),
    Mcp.tool("add", "Add two integers", schema.add())])

# echo's answer: the prefix and the text, or a refusal
def echo(prefix: String, meth: Maybe<&2, String>) -> Rpc.Out:
  match meth:
    case None{}:
      Mcp.refuse.params("echo: text must be a string")
    case Some{s}:
      Mcp.ok(Mcp.result.text(prefix ++ s))

# add's result: the sum as structured content, or a tool error
def add(lead: Maybe<&2, U32>, byte: Maybe<&2, U32>) -> Value.Json:
  match lead byte:
    case Some{x} Some{y}:
      Mcp.result.json(Json.obj([("sum", Json.num(U32.show(U32.add(x, y))))]))
    case x y:
      Mcp.result.error("add: a and b must be non-negative integers")

def run.of(prefix: String, +args: Value.Json, is_echo: Bool) -> IO(Rpc.Out):
  match is_echo:
    case True{}:
      IO.pure(Rpc.Out, echo(prefix, Json.as_str(Json.get(args, "text"))))
    case False{}:
      IO.pure(Rpc.Out, Mcp.ok(add(Json.as_u32(Json.get(args, "a")),
        Json.as_u32(Json.get(args, "b")))))

# ezmcp only runs tools the table names, so a name is echo or add; the
# prefix is the context the server was started with
def run(prefix: String, name: String, args: Value.Json) -> IO(Rpc.Out):
  run.of(prefix, args, String.eq(name, "echo"))

def http.limit(meth: Maybe<&1, String>) -> Maybe<&2, U32>:
  match meth:
    case None{}:
      None{}
    case Some{s}:
      U32.read(s)

# serve HTTP for a number of connections, or forever
@unsafe def http(+prefix: String, port: U32, limit: Maybe<&2, U32>) -> IO(Unit):
  match limit:
    case None{}:
      Mcp.http.serve_forever_with(~String, ~run, ~srv(), ~"/mcp", ~[], prefix,
        "127.0.0.1", port)
    case Some{n}:
      Mcp.http.serve_with(~String, ~run, ~srv(), ~"/mcp", ~[], prefix,
        "127.0.0.1", port, n)

# the prefix after an HTTP mode's count, if any
def http.prefix(rest: List<String>) -> String:
  match rest:
    case _n <> p <> _more:
      p
    case other:
      ""

# the mode the arguments name
@unsafe def mode(args: List<String>) -> IO(Unit):
  match args:
    case _prog <> "stdio" <> []:
      Mcp.stdio.serve_with(~String, ~run, ~srv(), "")
    case _prog <> "stdio" <> prefix <> _more:
      Mcp.stdio.serve_with(~String, ~run, ~srv(), prefix)
    case _prog <> "http" <> port <> +rest:
      http(http.prefix(rest), Maybe.default(&2, U32, U32.read(port), 8000),
        http.limit(List.head(&1, String, rest)))
    case other:
      IO.print_err("usage: demo stdio [PREFIX] | demo http PORT [N [PREFIX]]")

@unsafe def main() -> IO(Unit):
  IO.bind(List<String>, Unit, IO.args(), mode)
