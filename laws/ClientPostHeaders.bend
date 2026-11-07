# `basic/transports#sending-messages-to-the-server`: "The client **MUST**
# include an `Accept` header, listing both `application/json` and
# `text/event-stream`"; `#protocol-version-header`: "the client **MUST**
# include the `MCP-Protocol-Version: <protocol-version>` HTTP header on all
# subsequent requests". Every POST carries `Content-Type: application/json`
# and `Accept: application/json, text/event-stream`, and, once a version is
# negotiated (non-empty), `MCP-Protocol-Version` with it
import Base
import 0x7367809738fddd234b8d2bed772ad2cf/src/http.bend as Http
import ../src/client.bend as Client

# LAW: before initialize, a POST accepts JSON and event streams
law headers_first:
  for v: String
  for e: {String.is_empty(v) == True{} : Bool}
  {Client.headers(v)
    == [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"}]
    : List<&2, Http.Header>}

# LAW: after it, a POST also names the negotiated revision
law headers_version:
  for v: String
  for e: {String.is_empty(v) == False{} : Bool}
  {Client.headers(v)
    == [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"},
      Http.H{"MCP-Protocol-Version", v}] : List<&2, Http.Header>}
