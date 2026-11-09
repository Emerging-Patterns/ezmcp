# `server/tools`. A tool is a name, a description and an input schema
# (`Server.ToolSpec`); a server's tools are a table in a fixed order. A
# `tools/call` that names a known tool with valid arguments ends as a `Run`
# for the transport, which hands the name and the arguments to the server's
# runner and replies with `ran` of what the runner answers: `Rpc.Ok` of a
# tool result, or `Rpc.Err` of a JSON-RPC error it chose.
#
# `server/tools#listing-tools` and schema.json `ListToolsResult` (`tools`
# required) and `Tool` (`name` and `inputSchema` required). `tools/list` is
# answered with a result whose `tools` are every tool of the table, in table
# order, each exactly its `name`, `description` and `inputSchema`; the
# result has no `nextCursor`, so the list is one page
# (`server/utilities/pagination`)
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server

# LAW: tools/list is answered with the server's list
law list_dispatch:
  for srv: Server.Server
  for params: Value.Json
  {Server.dispatch(srv, "tools/list", params)
    == Server.Now{Rpc.Ok{Server.list(srv)}} : Server.Step}

# LAW: the list holds every tool of the table, in order
law list_items:
  for name: String
  for version: String
  for instructions: String
  for tools: List<&2, Server.ToolSpec>
  {Json.items(Json.get(Server.list(Server.Server{name, version, instructions,
    tools}), "tools")) == Server.tool.all(tools) : List<&2, Value.Json>}

# LAW: the list shows each tool by its own description
law list_each:
  for t: Server.ToolSpec
  for rest: List<&2, Server.ToolSpec>
  {Server.tool.all(t <> rest) == Server.tool.json(t) <> Server.tool.all(rest)
    : List<&2, Value.Json>}

# LAW: a tool shows its name, description and input schema
law tool_fields:
  for name: String
  for description: String
  for input: Value.Json
  {Server.tool.json(Server.ToolSpec{name, description, input})
    == Json.obj([("name", Json.str(name)),
      ("description", Json.str(description)), ("inputSchema", input)])
    : Value.Json}

# LAW: the list is one page: it has no nextCursor
law list_one_page:
  for srv: Server.Server
  {Json.has(Server.list(srv), "nextCursor") == False{} : Bool}
