# `server/tools#capabilities`: "Servers that support tools **MUST** declare
# the `tools` capability"; `basic/lifecycle#operation`: both parties
# "**MUST** ... Only use capabilities that were successfully negotiated."
# The result's `capabilities` are the tool table's: `{"tools":
# {"listChanged": false}}` when the table has a tool, and `{}` when it has
# none. ezmcp declares no other capability and sends no message of its own,
# so it uses none it did not declare
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/server.bend as Server

# LAW: the result's capabilities are the tool table's
law init_caps:
  for name: String
  for version: String
  for +instructions: String
  for tools: List<&2, Server.ToolSpec>
  for params: Value.Json
  {Json.get(Server.init(Server.Server{name, version, instructions, tools},
    params), "capabilities") == Server.capabilities(tools) : Value.Json}

# LAW: a server with tools declares the tools capability, listChanged false
law caps_tools:
  for t: Server.ToolSpec
  for rest: List<&2, Server.ToolSpec>
  {Json.get(Server.capabilities(t <> rest), "tools")
    == Json.obj([("listChanged", Json.bool(False{}))]) : Value.Json}

# LAW: a server with no tools declares no capability
law caps_none:
  for tools: List<&2, Server.ToolSpec>
  for e: {List.is_empty(&2, Server.ToolSpec, tools) == True{} : Bool}
  {Server.capabilities(tools) == Json.obj([]) : Value.Json}
