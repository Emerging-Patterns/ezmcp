# `2025-06-18/basic/transports#protocol-version-header` and
# `2025-11-25/basic/transports#protocol-version-header`: "If the server
# receives a request with an invalid or unsupported `MCP-Protocol-Version`,
# it **MUST** respond with `400 Bad Request`." A POST whose
# `MCP-Protocol-Version` header is present and names a revision ezmcp does
# not support is answered 400; an absent header, 2025-03-26, 2025-06-18 or
# 2025-11-25 passes
import Base
import ../src/server.bend as Server
import ../src/web.bend as Web

# LAW: an unsupported MCP-Protocol-Version is 400
law web_version:
  for srv: Server.Server
  for header: String
  for body: String
  for e: {Web.version.ok(header) == False{} : Bool}
  {Web.route(srv, True{}, True{}, True{}, header, body)
    == Web.text(400, "Bad Request: unsupported MCP-Protocol-Version")
    : Web.Web}

# LAW: a version header is acceptable when absent or supported, and only then
law version_ok:
  for v: String
  {Web.version.ok(v) == Bool.or(String.is_empty(v), Server.supported(v)) : Bool}
