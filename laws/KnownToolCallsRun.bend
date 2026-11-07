# `server/tools#calling-tools` and schema.json `CallToolRequest`
# (`params.name` a string, `params.arguments` an object). A `tools/call`
# whose `params.name` is a string that names a tool of the table, and whose
# `params.arguments` is an object or absent, ends as a tool call to run with
# that name and those arguments (`{}` when absent), under the request's id
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/server.bend as Server

# LAW: tools/call is the server's call step
law call_dispatch:
  for srv: Server.Server
  for params: Value.Json
  {Server.dispatch(srv, "tools/call", params) == Server.call(srv, params)
    : Server.Step}

# LAW: a tool the table names is known
law known_named:
  for name: String
  for description: String
  for input: Value.Json
  for rest: List<&2, Server.ToolSpec>
  {Server.known(Server.ToolSpec{name, description, input} <> rest, name)
    == True{} : Bool}

# LAW: a call of a known tool with object arguments runs it on them
law call_runs:
  for name: String
  for params: Value.Json
  for has: {Json.has(params, "arguments") == True{} : Bool}
  for obj: {Json.is_obj(Json.get(params, "arguments")) == True{} : Bool}
  {Server.call.known(name, params, True{})
    == Server.Call{name, Json.get(params, "arguments")} : Server.Step}

# LAW: a call of a known tool with no arguments runs it on {}
law call_no_args:
  for name: String
  for params: Value.Json
  for has: {Json.has(params, "arguments") == False{} : Bool}
  {Server.call.known(name, params, True{}) == Server.Call{name, Json.obj([])}
    : Server.Step}

# LAW: a call names its tool by params.name
law call_named:
  for name: String
  for description: String
  for version: String
  for instructions: String
  for tools: List<&2, Server.ToolSpec>
  for params: Value.Json
  for n: String
  for e: {Json.as_str(Json.get(params, "name")) == Some{n} : Maybe<&2, String>}
  {Server.call(Server.Server{name, version, instructions, tools}, params)
    == Server.call.known(n, params, Server.known(tools, n)) : Server.Step}

# LAW: a call to run is a Run with the request's id
law call_is_run:
  for id: Value.Json
  for name: String
  for args: Value.Json
  {Server.answer(id, Server.Call{name, args}) == Server.Run{id, name, args}
    : Server.Act}
