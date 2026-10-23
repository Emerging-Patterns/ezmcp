# ezmcp

[Model Context Protocol](https://modelcontextprotocol.io/specification)
servers and clients for [Bend 2](https://github.com/bendlang/bend), revisions
2025-03-26, 2025-06-18 and 2025-11-25: JSON-RPC 2.0 messages,
`initialize`, `ping`, `tools/list` and `tools/call`, served over streamable
HTTP (on [ezhttp](https://github.com/Emerging-Patterns/ezhttp)) or stdio,
and a client that speaks streamable HTTP.

## Install

With [Bend](https://github.com/bendlang/bend) alone there is nothing to
install: import ezmcp by its hub name and version, and `bend` fetches it from
[the hub](https://hub.bend-lang.com) into `~/.bend/lib` on the first run.
ezmcp is built and checked on Bend 2.0.38.

```
import emerging-ezmcp@0.1.0.0/main.bend as Mcp
```

`emerging-ezmcp@0.1.0.0` is ezmcp v0.1.0, once the release is published.

Or with [ez](https://github.com/Emerging-Patterns/ez), which records the
package in `ez.toml` (`ez init` makes one):

```
ez add Emerging-Patterns/ezmcp
```

Tool arguments and results are [ezjson](https://github.com/Emerging-Patterns/ezjson)
values. Build them with the ezjson ezmcp is locked to (v1.2.0), so the two
agree on the type: `ez add Emerging-Patterns/ezjson v1.2.0`.

ezmcp imports its dependencies by hash: ezjson v1.2.0
(`0xa81e161008ecc2f297c0a3065cb9b188`) and ezhttp v0.14.0
(`0xa4d47e5f0f6044ac1a983d1b051fa47a`). A project that uses ezhttp too
shares one copy with ezmcp only when it adds the same release
(`ez add Emerging-Patterns/ezhttp v0.14.0`); any other release is a second
package in its lock and its binary, and ezmcp's server runs on the one
ezmcp names. ez has no override or version range that redirects a
dependency's `0x` import, so the way to one copy is to keep the two
releases equal.

## A server

A server is a name, a version, instructions for the client and a tool
table. A runner, `String -> Json -> IO(Json)`, runs a tool by name on its
arguments and answers a tool result. ezmcp answers `initialize`, `ping` and
`tools/list` itself, refuses an unknown tool or arguments that are not an
object, and calls the runner only for a tool the table names.

```
import Base
import emerging-ezjson@1.2.0.0/main.bend as Json
import emerging-ezjson@1.2.0.0/src/value.bend as Value
import emerging-ezmcp@0.1.0.0/main.bend as Mcp
import emerging-ezmcp@0.1.0.0/src/server.bend as Server

def srv() -> Server.Server:
  Mcp.server("greeter", "0.1.0", "", [
    Mcp.tool("greet", "Greet someone by name",
      Json.obj([("type", Json.str("object")),
        ("properties", Json.obj([("name",
          Json.obj([("type", Json.str("string"))]))])),
        ("required", Json.arr([Json.str("name")]))]))])

def greeting(name: Maybe<&2, String>) -> Value.Json:
  match name:
    case None{}:
      Mcp.result.error("name must be a string")
    case Some{n}:
      Mcp.result.text("Hello, " ++ n ++ "!")

def run(_tool: String, args: Value.Json) -> IO(Value.Json):
  IO.pure(Value.Json, greeting(Json.as_str(Json.get(args, "name"))))

@unsafe def main() -> IO(Unit):
  Mcp.http.serve_forever(~run, ~srv(), ~"/mcp", ~[], "127.0.0.1", 8000)
```

`Mcp.stdio.serve(~run, ~srv())` serves the same server on stdin and stdout
instead; write logs with `IO.print_err`, never to stdout. To mount the
endpoint in an ezhttp server that serves other paths too, hand requests to
`Mcp.http.handle(~run, ~srv, ~path, ~origins, req)`.

| Name | Type | What it does |
| :---- | :---- | :---- |
| `tool(name, description, input_schema)` | `Server.Tool` | a tool table entry |
| `server(name, version, instructions, tools)` | `Server.Server` | a server; `""` for no instructions |
| `result.text(s)` | `Json` | a tool result of one text block |
| `result.error(s)` | `Json` | a failed tool's result: one text block, `isError` true |
| `result.json(v)` | `Json` | structured content, and its JSON text as a text block |
| `result(blocks, is_error)` | `Json` | a tool result from any content blocks |
| `text(s)` | `Json` | a text content block |
| `http.serve_forever(~run, ~srv, ~path, ~origins, host, port)` | `IO(Unit)` | serve the endpoint until the process stops (`@unsafe`) |
| `http.serve(~run, ~srv, ~path, ~origins, host, port, limit)` | `IO(Unit)` | serve `limit` connections |
| `http.handle(~run, ~srv, ~path, ~origins, req)` | `IO(Http.Reply)` | one request, as an ezhttp IO handler |
| `http.decide(srv, path, origins, req)` | `Web.Web` | the transport's decision for one request, with no IO |
| `stdio.serve(~run, ~srv)` | `IO(Unit)` | serve stdin and stdout until stdin ends (`@unsafe`) |
| `step(srv, rev, text)` | `Server.Act` | what a server does with one message read by revision `rev`, for a transport of your own |
| `turn(srv, rev, text)` | `Server.Turn` | `step`'s act and the revision a stream's next message is read by |
| `ran(rev, id, result)` | `Json` | the reply to a tool call once it ran |
| `batch.reply(replies)` | `Maybe<Json>` | what a 2025-03-26 batch sends back, from its acts' replies |
| `latest()` | `String` | `"2025-11-25"` |
| `revisions()` | `List<String>` | the revisions ezmcp speaks, oldest first |

Over HTTP every POST is answered with one JSON body (200), or 202 for a
notification; GET and DELETE are 405, another path is 404, and an
`MCP-Protocol-Version` ezmcp does not speak is 400.

### Protocol revisions

ezmcp speaks 2025-03-26, 2025-06-18 and 2025-11-25. `initialize` answers
the revision the client asks for when it is one of them, and 2025-11-25
otherwise. Over HTTP a request is read by the revision its
`MCP-Protocol-Version` names, and by 2025-03-26 when it names none, as the
specification asks; over stdio by the one the last `initialize` was answered
with. Under 2025-03-26 a JSON-RPC batch (an array) is answered with an array
of replies (202 over HTTP when it holds none), and a tool result leaves out
`structuredContent`, which that revision does not have: `result.json`'s
text block still carries the value. Under the later two an array is an
invalid request. An `Origin` header is
allowed when it is a page on this machine (`localhost`, `127.0.0.1`, `[::1]`)
or one of `origins`; any other is 403, which stops DNS rebinding. Bind
`127.0.0.1` unless the endpoint sits behind a proxy that authenticates:
ezmcp does no authorization.

## A client

```
reply : Rpc.Reply <- Mcp.client.ask(url, "", 30000,
  Mcp.client.initialize(Json.num("1"), "my-client", "0.1.0"))
```

`client.ask(url, version, timeout_ms, msg)` POSTs one request and reads the
reply, whether the server answers JSON or an event stream, as
`Rpc.Got{id, result}`, `Rpc.Refused{id, code, message}` or `Rpc.Unread{why}`
(import `src/rpc.bend` for the constructors). `client.tell` POSTs a
notification. Pass the revision `client.version(result)` reads from the
initialize result as `version` from then on. `client.initialize`,
`client.initialized()`, `client.tools(id)` and `client.call(id, name, args)`
build the messages. The client has no sessions, so it talks to stateless
servers.

## Examples

```
git clone https://github.com/Emerging-Patterns/ezmcp
cd ezmcp && nix develop
ez fetch
cd examples/demo && bend main.bend -o demo
./demo stdio                    # or: ./demo http 8000
```

`examples/demo` serves two tools (`echo`, and `add` with structured
content and a tool error); `examples/client` runs a session against any
endpoint (`./client http://127.0.0.1:8000/mcp add '{"a":2,"b":40}'`);
`examples/conformance` serves the tools the
[MCP conformance suite](https://github.com/modelcontextprotocol/conformance)
calls. Build on the C lane (`-o`): the JS lane runs out of stack on large
bodies.

## Guarantees

[SPEC.md](SPEC.md) lists every behavior ezmcp guarantees, each a requirement
of MCP 2025-03-26, 2025-06-18 or 2025-11-25, or of JSON-RPC 2.0, cited by
section, either proved by a
quantified law in `LAWS.bend` or named as a trusted assumption. A row marked
pending is not guaranteed yet. Its last table lists the revisions'
requirements for what ezmcp does not implement: resources, prompts, logging,
completions, sampling, elicitation, roots, progress, cancellation, SSE
streams on the server, sessions, pagination and authorization.

`nix flake check` runs the proof gate (`bend PROOF.bend` must print exactly
`ALL PROOFS CHECK` first), the entry check, a smoke run of the examples on
the C lane, and bolt, whose `trace` rule checks that SPEC.md and the laws
agree.

## License

MIT, see [LICENSE](LICENSE).
