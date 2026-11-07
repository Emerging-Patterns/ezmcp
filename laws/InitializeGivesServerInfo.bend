# `Server.init` builds the `initialize` result from the server and the
# request's params. A server is stateless: it answers every request on its
# own, so a client may call `initialize` more than once. `Server.turn` acts
# on one message's text under the revision it is read by, and says which
# revision the stream's next message is read by.
#
# `basic/lifecycle#initialization`: "The server **MUST** respond with its
# own capabilities and information." `initialize` is answered with a result
# whose `serverInfo` is exactly the server's `name` and `version`
# (schema.json `Implementation`), with `instructions` when the server has
# non-empty instructions and with no `instructions` member when it has none
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server

# LAW: initialize is answered with the server's initialize result
law initialize_dispatch:
  for srv: Server.Server
  for params: Value.Json
  {Server.dispatch(srv, "initialize", params)
    == Server.Now{Rpc.Ok{Server.init(srv, params)}} : Server.Step}

# LAW: the result names the server's name and version
law init_info:
  for name: String
  for version: String
  for +instructions: String
  for tools: List<&2, Server.ToolSpec>
  for params: Value.Json
  {Json.get(Server.init(Server.Server{name, version, instructions, tools},
    params), "serverInfo")
    == Json.obj([("name", Json.str(name)), ("version", Json.str(version))])
    : Value.Json}

# LAW: the result carries instructions when the server has some
law init_instructions:
  for name: String
  for version: String
  for +instructions: String
  for tools: List<&2, Server.ToolSpec>
  for params: Value.Json
  for e: {String.is_empty(instructions) == False{} : Bool}
  {Json.get(Server.init(Server.Server{name, version, instructions, tools},
    params), "instructions") == Json.str(instructions) : Value.Json}

# LAW: and none when it has none
law init_no_instructions:
  for name: String
  for version: String
  for +instructions: String
  for tools: List<&2, Server.ToolSpec>
  for params: Value.Json
  for e: {String.is_empty(instructions) == True{} : Bool}
  {Json.has(Server.init(Server.Server{name, version, instructions, tools},
    params), "instructions") == False{} : Bool}
