# `server/tools#error-handling`: "Tool Execution Errors: Reported in tool
# results with `isError: true`"; schema.json `CallToolResult` (`content`
# required) and `TextContent` (`type` "text" and `text` required).
# `result(blocks, bad)` is a tool result whose `content` is exactly the
# blocks in order and whose `isError` is `bad`; `text(s)` is exactly the
# TextContent `{"type": "text", "text": s}`; the reply to a run tool call
# has the runner's answer as its `result`, under every revision but
# 2025-03-26 (laws/OldRevisionDropsStructuredContent.bend)
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server

# LAW: a tool result's isError is the flag it was given
law result_flag:
  for blocks: List<&2, Value.Json>
  for bad: Bool
  {Json.get(Server.result(blocks, bad), "isError") == Json.bool(bad)
    : Value.Json}

# LAW: a tool result's content is its blocks, in order
law result_content:
  for blocks: List<&2, Value.Json>
  for bad: Bool
  {Json.items(Json.get(Server.result(blocks, bad), "content")) == blocks
    : List<&2, Value.Json>}

# LAW: a text block is a TextContent
law text_block:
  for s: String
  {Server.text(s) == Json.obj([("type", Json.str("text")), ("text", Json.str(s))])
    : Value.Json}

# LAW: the reply to a tool call is a result holding the tool's result, under
# any revision but 2025-03-26
law ran_result:
  for rev: String
  for id: Value.Json
  for result: Value.Json
  for e: {String.eq(rev, "2025-03-26") == False{} : Bool}
  {Json.get(Server.ran(rev, id, Rpc.Ok{result}), "result") == result
    : Value.Json}
