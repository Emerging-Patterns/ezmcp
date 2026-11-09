# `basic/utilities/ping#behavior-requirements`: "The receiver **MUST**
# respond promptly with an empty response." For every server and params,
# `ping` ends with the result `{}`
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server

# LAW: ping is answered with an empty result
law ping_empty:
  for srv: Server.Server
  for params: Value.Json
  {Server.dispatch(srv, "ping", params) == Server.Now{Rpc.Ok{Json.obj([])}}
    : Server.Step}
