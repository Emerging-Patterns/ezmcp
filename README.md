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
import ezmcp@0.1.0.0/main.bend as Mcp
```

`ezmcp@0.1.0.0` is ezmcp v0.1.0 and resolves to
`0xe8a45a5d2dbc02504d10df4cabf172ea`; to pin by content, import
`0xe8a45a5d2dbc02504d10df4cabf172ea/main.bend` instead.

Or with [ez](https://github.com/Emerging-Patterns/ez), which records the
package in `ez.toml` (`ez init` makes one):

```
ez add Emerging-Patterns/ezmcp
```

Tool arguments and results are [ezjson](https://github.com/Emerging-Patterns/ezjson)
values. Build them with the ezjson ezmcp is locked to (v1.2.0), so the two
agree on the type: `ez add Emerging-Patterns/ezjson v1.2.0`.

ezmcp imports its dependencies by hash: ezjson v1.2.0
(`0xa81e161008ecc2f297c0a3065cb9b188`) and ezhttp at `cab153b`
(`0xedb2120a04a47dc18c3a756ec7c62750`). A project that uses ezhttp too
shares one copy with ezmcp only when it adds the same commit
(`ez add https://github.com/Emerging-Patterns/ezhttp cab153b2bf4308127f454d8e204e6c85ae50aaaa`);
any other commit is a second
package in its lock and its binary, and ezmcp's server runs on the one
ezmcp names. ez has no override or version range that redirects a
dependency's `0x` import, so the way to one copy is to keep the two
releases equal.

## A server

A server is a name, a version, instructions for the client and a tool
table. A runner, `String -> Json -> IO(Rpc.Out)`, runs a tool by name on its
arguments and answers `Mcp.ok` of a tool result, or refuses the call with a
JSON-RPC error: `Mcp.refuse.params(message)` (-32602, for arguments that do
not match the tool's schema), `Mcp.refuse.internal(message)` (-32603), or
`Mcp.refuse(code, message)`. A tool that ran and failed answers
`Mcp.ok(Mcp.result.error(...))` instead, so the model sees the failure and
can retry; 2025-11-25 asks for input validation errors to be reported that
way too. ezmcp answers `initialize`, `ping` and `tools/list` itself, refuses
an unknown tool or arguments that are not an object, and calls the runner
only for a tool the table names.

```
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ezmcp@0.1.0.0/main.bend as Mcp
import ezmcp@0.1.0.0/src/rpc.bend as Rpc
import ezmcp@0.1.0.0/src/server.bend as Server

def srv() -> Server.Server:
  Mcp.server("greeter", "0.1.0", "", [
    Mcp.tool("greet", "Greet someone by name",
      Json.obj([("type", Json.str("object")),
        ("properties", Json.obj([("name",
          Json.obj([("type", Json.str("string"))]))])),
        ("required", Json.arr([Json.str("name")]))]))])

def greeting(name: Maybe<&2, String>) -> Rpc.Out:
  match name:
    case None{}:
      Mcp.refuse.params("name must be a string")
    case Some{n}:
      Mcp.ok(Mcp.result.text("Hello, " ++ n ++ "!"))

def run(_tool: String, args: Value.Json) -> IO(Rpc.Out):
  IO.pure(Rpc.Out, greeting(Json.as_str(Json.get(args, "name"))))

@unsafe def main() -> IO(Unit):
  Mcp.http.serve_forever(~run, ~srv(), ~"/mcp", ~[], "127.0.0.1", 8000)
```

### A runner with a context

A runner passed as `~run` is a closed template: it can call top-level
defs, but it cannot capture a value the program reads at run time, such as
its arguments, an environment variable or a base URL. The `_with` serves
take a context of any `Data` type and hand it to the runner on every call:

```
def run(base: String, tool: String, args: Value.Json) -> IO(Rpc.Out):
  ...

@unsafe def main() -> IO(Unit):
  IO.bind(String, Unit, IO.try(String, IO.get_env("API_BASE")),
    base => Mcp.http.serve_forever_with(~String, ~run, ~srv(), ~"/mcp", ~[],
      base, "127.0.0.1", 8000, 0))
```

`Mcp.stdio.serve_with(~C, ~run, ~srv, ctx)`, `Mcp.http.serve_with` (for
`limit` connections) and `Mcp.http.handle_with` do the same.

A server built at run time, from a document read at startup say, cannot be
a `~srv` either. The `_from` serves take the server from the context too,
as `srv(ctx)`, on every request:

```
Mcp.http.serve_forever_from(~Api, ~api.srv, ~run, ~"/mcp", ~[], api,
  "0.0.0.0", 3000, 0)
```

`Mcp.http.serve_from` (for `limit` connections) and `Mcp.http.handle_from`
do the same.

### Connections at once

The HTTP serves run on ezhttp, which serves each connection on its own
fork, so slow tool calls from different clients (or one client's
concurrent requests) overlap. ezmcp keeps nothing between requests, so the
runner is the only place two calls can meet. `http.serve` and
`http.serve_forever` take as many connections at once as arrive; the
`_with` serves take a last argument `max`, the most at once (`0` for no
limit, `1` to run one call at a time, as for a tool that drives one
browser).

`Mcp.stdio.serve(~run, ~srv())` serves the same server on stdin and stdout
instead; write logs with `IO.print_err`, never to stdout. To mount the
endpoint in an ezhttp server that serves other paths too, hand requests to
`Mcp.http.handle(~run, ~srv, ~path, ~origins, req)`.

| Name | Type | What it does |
| :---- | :---- | :---- |
| `tool(name, description, input_schema)` | `Server.Tool` | a tool table entry |
| `ok(result)` | `Rpc.Out` | a runner's answer: this tool result |
| `refuse(code, message)` | `Rpc.Out` | a runner's answer: this JSON-RPC error, not a tool result |
| `refuse.params(message)` | `Rpc.Out` | refuse with -32602 Invalid params |
| `refuse.internal(message)` | `Rpc.Out` | refuse with -32603 Internal error |
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
| `http.serve_forever_with(~C, ~run, ~srv, ~path, ~origins, ctx, host, port, max)` | `IO(Unit)` | `http.serve_forever` with a runner `C -> String -> Json -> IO(Rpc.Out)` given `ctx`, at most `max` connections at once (0: no limit) (`@unsafe`) |
| `http.serve_with(~C, ~run, ~srv, ~path, ~origins, ctx, host, port, limit, max)` | `IO(Unit)` | `http.serve` with a context, at most `max` connections at once |
| `http.handle_with(~C, ~run, ~srv, ~path, ~origins, ctx, req)` | `IO(Http.Reply)` | `http.handle` with a context |
| `stdio.serve_with(~C, ~run, ~srv, ctx)` | `IO(Unit)` | `stdio.serve` with a context (`@unsafe`) |
| `http.serve_forever_from(~C, ~srv, ~run, ~path, ~origins, ctx, host, port, max)` | `IO(Unit)` | `http.serve_forever_with` with the server `srv(ctx)` (`@unsafe`) |
| `http.serve_from(~C, ~srv, ~run, ~path, ~origins, ctx, host, port, limit, max)` | `IO(Unit)` | `http.serve_with` with the server `srv(ctx)` |
| `http.handle_from(~C, ~srv, ~run, ~path, ~origins, ctx, req)` | `IO(Http.Reply)` | `http.handle_with` with the server `srv(ctx)` |
| `step(srv, rev, text)` | `Server.Act` | what a server does with one message read by revision `rev`, for a transport of your own |
| `turn(srv, rev, text)` | `Server.Turn` | `step`'s act and the revision a stream's next message is read by |
| `ran(rev, id, out)` | `Json` | the reply to a tool call once the runner answered |
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

## OpenAPI

`src/openapi.bend` reads an OpenAPI 3.0 or 3.1 document (a JSON value) as
a tool table, one tool for each operation, and a tool call as the HTTP
request it stands for:

```
ops : List<Openapi.Op> = Mcp.openapi.ops(doc)
srv = Mcp.server("pets", "1.0.0", "", tools(ops))  # openapi.tool of each
```

A tool is named by its operationId (sanitized to `[A-Za-z0-9_-]`, or
one made from the method and path when there is none, `PostPets` for
`POST /pets`) and described by its description or
summary; its input schema has a property for each path, query and header
parameter and a `requestBody` property for a JSON or text body, with
local references (`#/...`) followed. In the runner, `openapi.check(op,
args)` says what is wrong with the arguments (refuse with
`refuse.params`), and `openapi.call(op, args)` is
`Send{method, target, headers, body}`, the target being the path and query
to append to the API's base URL, or `Unfilled{path}` when a path parameter
has no argument. Send it with ezhttp. The table and the requests follow
openapi-mcp-generator 4, so a server built on them answers like the
adapters it generates. `openapi.renamed(op, name)` renames a tool, for a
client that limits names.

Servers, security schemes, external references, cookie parameters and
parameter styles other than the default are not read: the caller supplies
the base URL and any credentials. `examples/openapi` serves a small
document.

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

The client runs on ezhttp's sockets (bend-kit-wire). For an `https://`
endpoint OpenSSL 3 is loaded at run time; point `BEND_LIBSSL` at
`libssl.so.3` when it is not where the loader looks (`EZ_LIBSSL` is no
longer read).

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
calls; `examples/openapi` serves an OpenAPI document's operations,
answering each call with the request it stands for
(`./openapi list`, `./openapi call get_pet '{"pet_id":7}'`,
`./openapi http 8000 10`). Build on the C lane (`-o`): the JS lane runs out of stack on large
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
`ALL PROOFS CHECK` first), a smoke run of the examples on the C lane, and
bolt, whose `trace` rule checks that SPEC.md and the laws agree and whose
`coverage` rule, an error, checks that a law reaches every def. A def no law
can reach (a re-export in `main.bend`, a closed constant, a def only
`src/io.bend` calls, an example's) carries a `# noqa: L001` naming why.

## License

MIT, see [LICENSE](LICENSE).
