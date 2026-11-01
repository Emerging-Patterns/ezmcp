# `basic/transports#sending-messages-to-the-server`: "If the server cannot
# accept the input, it **MUST** return an HTTP error status code (e.g., 400
# Bad Request). The HTTP response body **MAY** comprise a JSON-RPC _error
# response_". A body that is not JSON or not a valid message
# (laws/UnparsedTextIsParseError.bend, laws/InvalidRequestsFault.bend) is
# answered 400 with its JSON-RPC error as the body; an HTTP request that
# does not parse is answered 400
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import 0xedb2120a04a47dc18c3a756ec7c62750/src/http.bend as Http
import ../src/server.bend as Server
import ../src/web.bend as Web

# LAW: a message the server cannot accept is 400, with its JSON-RPC error
law web_fault:
  for rev: String
  for reply: Value.Json
  {Web.act(rev, Server.Fault{reply})
    == Web.Now{400, [Http.H{"Content-Type", "application/json"}],
      Json.print(reply)} : Web.Web}

# LAW: an HTTP request that does not parse is 400
law web_bad:
  for srv: Server.Server
  for path: String
  for origins: List<&2, String>
  for why: String
  {Web.decide(srv, path, origins, Http.Bad{why}) == Web.text(400, why)
    : Web.Web}
