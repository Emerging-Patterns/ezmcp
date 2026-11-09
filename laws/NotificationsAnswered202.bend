# `basic/transports#sending-messages-to-the-server`: "If the input is a
# JSON-RPC _response_ or _notification_: If the server accepts the input,
# the server **MUST** return HTTP status code 202 Accepted with no body."
# Every notification and every response is answered 202 with no headers and
# no body
import Base
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server
import ../src/web.bend as Web

# LAW: a notification is accepted: 202, no body
law web_tell:
  for rev: String
  for srv: Server.Server
  for m: String
  for params: Value.Json
  {Web.act(rev, Server.handle(srv, Rpc.Tell{m, params})) == Web.Now{202, [], ""}
    : Web.Web}

# LAW: a response is accepted: 202, no body
law web_answer:
  for rev: String
  for srv: Server.Server
  for id: Value.Json
  {Web.act(rev, Server.handle(srv, Rpc.Answer{id})) == Web.Now{202, [], ""}
    : Web.Web}
