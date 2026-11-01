# `basic/transports#streamable-http`: "The server **MUST** provide a single
# HTTP endpoint path". Every request whose target's path (the target before
# any `?`) is not the endpoint's path is answered 404, whatever its method
# or Origin
import Base
import ../src/server.bend as Server
import ../src/web.bend as Web

# LAW: a request to another path is 404
law web_path:
  for srv: Server.Server
  for allowed: Bool
  for is_post: Bool
  for header: String
  for body: String
  {Web.route(srv, False{}, allowed, is_post, header, body)
    == Web.text(404, "Not Found") : Web.Web}
