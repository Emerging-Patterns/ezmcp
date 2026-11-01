# `basic/transports#security-warning` (all three revisions): "Servers
# **MUST** validate the `Origin` header on all incoming connections to
# prevent DNS rebinding attacks";
# `2025-11-25/basic/transports#security-warning`: "If the `Origin` header is
# present and invalid, servers **MUST** respond with HTTP 403 Forbidden." A
# request to the endpoint whose Origin is not allowed is answered 403,
# whatever its method. An Origin is allowed exactly when it is absent (a
# client that is not a browser), when it is a page on this machine
# (`http://` or `https://`, then `localhost`, `127.0.0.1` or `[::1]`, then
# nothing or `:` and a port's digits), or when the server's list names it
# exactly; so with an empty list, a rebinding page's Origin (any other host)
# is refused
import Base
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server
import ../src/web.bend as Web

# LAW: a request whose Origin is not allowed is 403, whatever its method
law web_origin:
  for srv: Server.Server
  for is_post: Bool
  for header: String
  for body: String
  {Web.route(srv, True{}, False{}, is_post, header, body)
    == Web.text(403, "Forbidden: Origin not allowed") : Web.Web}

# LAW: a request with no Origin passes
law origin_absent:
  for origins: List<&2, String>
  {Web.origin.ok(origins, "") == True{} : Bool}

# LAW: a page on this machine passes
law origin_loopback:
  for origins: List<&2, String>
  for origin: String
  for e: {Web.loopback(origin) == True{} : Bool}
  {Web.origin.ok(origins, origin) == True{} : Bool}

# LAW: http://localhost with a port is a page on this machine
law loopback_localhost:
  for port: String
  {Web.loopback("http://localhost:" ++ port) == Rpc.digits(port) : Bool}

# LAW: http://127.0.0.1 with a port is a page on this machine
law loopback_ipv4:
  for port: String
  {Web.loopback("http://127.0.0.1:" ++ port) == Rpc.digits(port) : Bool}

# LAW: any other Origin passes exactly when the server lists it
law origin_other:
  for origins: List<&2, String>
  for origin: String
  for ee: {String.is_empty(origin) == False{} : Bool}
  for el: {Web.loopback(origin) == False{} : Bool}
  {Web.origin.ok(origins, origin) == Web.origin.listed(origins, origin) : Bool}

# LAW: a listed Origin is listed
law origin_listed:
  for origin: String
  for rest: List<&2, String>
  {Web.origin.listed(origin <> rest, origin) == True{} : Bool}

# LAW: an empty list lists no Origin
law origin_none:
  for origin: String
  {Web.origin.listed([], origin) == False{} : Bool}

# LAW: an Origin the list's first entry is not is listed only if the rest
# lists it
law origin_unlisted:
  for listed: String
  for rest: List<&2, String>
  for origin: String
  for e: {String.eq(listed, origin) == False{} : Bool}
  {Web.origin.listed(listed <> rest, origin) == Web.origin.listed(rest, origin)
    : Bool}
