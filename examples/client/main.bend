# examples/client: an MCP client session over streamable HTTP.
#
#   client URL TOOL ARGS-JSON
#
# initialize, notifications/initialized, tools/list, then tools/call of TOOL
# on ARGS-JSON, printing what each reply says.
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../../main.bend as Mcp
import ../../src/rpc.bend as Rpc

# milliseconds each exchange may take
def timeout() -> U32:  # noqa: L001 example program, no law's subject
  30000

# a reply as one line
def shown(reply: Rpc.Reply) -> String:  # noqa: L001 example program, no law's subject
  match reply:
    case Rpc.Got{id, result}:
      "got " ++ Json.print(id) ++ " " ++ Json.print(result)
    case Rpc.Refused{id, code, message}:
      "refused " ++ Json.print(id) ++ " " ++ code ++ " " ++ message
    case Rpc.Unread{why}:
      "unread " ++ why

# the revision a reply to initialize names
def version(reply: Rpc.Reply) -> String:  # noqa: L001 example program, no law's subject
  match reply:
    case Rpc.Got{_id, result}:
      Mcp.client.version(result)
    case _other:
      ""

# the arguments, {} when they are not JSON
def args(text: String) -> Value.Json:  # noqa: L001 example program, no law's subject
  Maybe.default(&2, Value.Json, Json.parse(text), Json.obj([]))

# list the tools, then call one
def rest(+url: String, +ver: String, tool: String, input: String) -> IO(Unit):  # noqa: L001 example program
  do IO<Unit>:
    +told : Bool <- Mcp.client.tell(url, ver, timeout(), Mcp.client.initialized())
    _a : Unit <- IO.print("initialized accepted: " ++ Bool.show(told))
    listed : Rpc.Reply <- Mcp.client.ask(url, ver, timeout(),
      Mcp.client.tools(Json.num("2")))
    _b : Unit <- IO.print(shown(listed))
    called : Rpc.Reply <- Mcp.client.ask(url, ver, timeout(),
      Mcp.client.call(Json.num("3"), tool, args(input)))
    IO.print(shown(called))

# a session against one endpoint
def session(+url: String, tool: String, input: String) -> IO(Unit):  # noqa: L001 example program, no law's subject
  do IO<Unit>:
    +init : Rpc.Reply <- Mcp.client.ask(url, "", timeout(),
      Mcp.client.initialize(Json.num("1"), "ezmcp-client", "0.1.0"))
    _a : Unit <- IO.print(shown(init))
    rest(url, version(init), tool, input)

# the session the arguments name
def mode(argv: List<String>) -> IO(Unit):  # noqa: L001 example program, no law's subject
  match argv:
    case _prog <> url <> tool <> input <> _more:
      session(url, tool, input)
    case _other:
      IO.print_err("usage: client URL TOOL ARGS-JSON")

def main() -> IO(Unit):  # noqa: L001 example program, no law's subject
  IO.bind(List<String>, Unit, IO.args(), mode)
