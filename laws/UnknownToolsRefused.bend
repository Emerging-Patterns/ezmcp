# `server/tools#error-handling`: "Protocol Errors: Standard JSON-RPC errors
# for issues like: Unknown tools". A `tools/call` whose name no tool of the
# table has ends with error -32602 `Unknown tool: <name>`, the spec's own
# example, and runs nothing
import Base
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server

# LAW: a call of an unknown tool is invalid params
law call_unknown:
  for name: String
  for params: Value.Json
  {Server.call.known(name, params, False{})
    == Server.Now{Rpc.Err{Rpc.InvalidParams{}, "Unknown tool: " ++ name}}
    : Server.Step}

# LAW: no tool is known to an empty table
law known_none:
  for name: String
  {Server.known([], name) == False{} : Bool}
