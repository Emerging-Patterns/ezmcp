# `basic/transports#listening-for-messages-from-the-server`: "The server
# **MUST** either return `Content-Type: text/event-stream` in response to
# this HTTP GET, or else return HTTP 405 Method Not Allowed";
# `#session-management`: to DELETE "The server **MAY** respond ... with HTTP
# 405". Every method but POST (GET and DELETE included) at the endpoint,
# with an allowed Origin, is answered 405 with `Allow: POST` and no body
import Base
import ezhttp@0.23.0.0/src/http.bend as Http
import ../src/server.bend as Server
import ../src/web.bend as Web

# LAW: any method but POST is 405, with Allow: POST
law web_not_post:
  for srv: Server.Server
  for header: String
  for body: String
  {Web.route(srv, True{}, True{}, False{}, header, body)
    == Web.Now{405, [Http.H{"Allow", "POST"}], ""} : Web.Web}
