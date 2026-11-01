# `server/tools#error-handling`: "Protocol Errors ... Invalid arguments". A
# `tools/call` whose `params.name` is not a string, or whose
# `params.arguments` is present and not an object, ends with error -32602
# and runs nothing
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server

# LAW: a call whose name is not a string is invalid params
law call_no_name:
  for srv: Server.Server
  for params: Value.Json
  for e: {Json.as_str(Json.get(params, "name")) == None{} : Maybe<&2, String>}
  {Server.call(srv, params)
    == Server.Now{Rpc.Err{Rpc.InvalidParams{},
      "tools/call: params.name must be a string"}} : Server.Step}

# LAW: a call whose arguments are not an object is invalid params
law call_bad_args:
  for name: String
  for params: Value.Json
  for has: {Json.has(params, "arguments") == True{} : Bool}
  for obj: {Json.is_obj(Json.get(params, "arguments")) == False{} : Bool}
  {Server.call.known(name, params, True{})
    == Server.Now{Rpc.Err{Rpc.InvalidParams{},
      "tools/call: arguments must be an object"}} : Server.Step}
