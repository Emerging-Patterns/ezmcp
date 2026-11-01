# JSON-RPC §5.1: -32601 Method not found, "The method does not exist / is
# not available." A request is answered by its method's step, and a request
# for any method other than `initialize`, `ping`, `tools/list` and
# `tools/call` ends with error -32601 `Method not found: <method>`
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server

# LAW: a request for a method the server does not have is method not found
law method_not_found:
  for srv: Server.Server
  for m: String
  for params: Value.Json
  for e: {Server.method.of(m) == Server.Other{} : Server.Method}
  {Server.dispatch(srv, m, params)
    == Server.Now{Rpc.Err{Rpc.MethodNotFound{}, "Method not found: " ++ m}}
    : Server.Step}

# LAW: a request is answered by its method's step
law ask_dispatch:
  for srv: Server.Server
  for id: Value.Json
  for m: String
  for params: Value.Json
  {Server.handle(srv, Rpc.Ask{id, m, params})
    == Server.answer(id, Server.dispatch(srv, m, params)) : Server.Act}
