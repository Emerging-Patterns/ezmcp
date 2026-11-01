# `2025-06-18/basic/transports#protocol-version-header` and
# `2025-11-25/basic/transports#protocol-version-header`: "if the server does
# _not_ receive an `MCP-Protocol-Version` header, and has no other way to
# identify the version ... the server **SHOULD** assume protocol version
# `2025-03-26`." A stateless server has no other way, so a POST is read by
# the revision its header names, and by 2025-03-26 when it has none
import Base
import ../src/server.bend as Server
import ../src/web.bend as Web

# LAW: a POST to the endpoint that passes the checks is the server's step,
# under the revision its header names
law web_post:
  for srv: Server.Server
  for +header: String
  for body: String
  for e: {Web.version.ok(header) == True{} : Bool}
  {Web.route(srv, True{}, True{}, True{}, header, body)
    == Web.act(Web.revision(header),
      Server.step(srv, Web.revision(header), body)) : Web.Web}

# LAW: a POST with no MCP-Protocol-Version is read by 2025-03-26
law revision_absent:
  for v: String
  for e: {String.is_empty(v) == True{} : Bool}
  {Web.revision(v) == "2025-03-26" : String}

# LAW: one with a header is read by the revision it names
law revision_named:
  for v: String
  for e: {String.is_empty(v) == False{} : Bool}
  {Web.revision(v) == v : String}
