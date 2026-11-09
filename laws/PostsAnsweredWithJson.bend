# `basic/transports#streamable-http`, which 2025-03-26 introduced and
# 2025-11-25 keeps. `Web.decide` takes one HTTP request (as ezhttp parses
# it) to a server's MCP endpoint and decides the reply, or a tool call or a
# batch to run first. Its order is: the path, then the `Origin`, then the
# method, then `MCP-Protocol-Version`, then the body. Every reply is a
# single response with a body; ezmcp never opens an SSE stream and never
# issues a session.
#
# `basic/transports#sending-messages-to-the-server`: "If the input is a
# JSON-RPC _request_, the server **MUST** either return `Content-Type:
# text/event-stream` ... or `Content-Type: application/json`, to return one
# JSON object." A POST to the endpoint that passes the checks below is
# decided by the server's step on its body, read by the request's revision
# (laws/RevisionFromVersionHeader.bend), and a request's reply, or a run
# tool call's, is status 200 with `Content-Type: application/json` and one
# JSON object, the reply's JSON text
#
# also rests on: laws/RevisionFromVersionHeader.bend
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ezhttp@0.23.0.0/src/http.bend as Http
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server
import ../src/web.bend as Web

# LAW: a request's HTTP decision is made from its path, Origin, method,
# MCP-Protocol-Version and body
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
      Http.headers.find(headers, "MCP-Protocol-Version"), body)
    : Web.Web}

# LAW: a request's reply is 200 with one JSON body
law web_send:
  for rev: String
  for reply: Value.Json
  {Web.act(rev, Server.Send{reply})
    == Web.Now{200, [Http.H{"Content-Type", "application/json"}],
      Json.print(reply)} : Web.Web}

# LAW: a tool call's reply is 200 with one JSON body
law web_ran:
  for rev: String
  for id: Value.Json
  for out: Rpc.Out
  {Web.ran(rev, id, out)
    == Web.Now{200, [Http.H{"Content-Type", "application/json"}],
      Json.print(Server.ran(rev, id, out))} : Web.Web}

# LAW: a tool call is run, under the request's revision, before the reply
law web_run:
  for rev: String
  for id: Value.Json
  for name: String
  for args: Value.Json
  {Web.act(rev, Server.Run{id, name, args}) == Web.Later{rev, id, name, args}
    : Web.Web}
