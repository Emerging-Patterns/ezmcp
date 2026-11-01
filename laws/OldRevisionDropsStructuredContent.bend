# `2025-06-18/changelog`: "Add support for structured tool output", which
# 2025-03-26's `CallToolResult` (`2025-03-26/server/tools#tool-result`) does
# not have; `server/tools#structured-content`: the text block is there "For
# backwards compatibility". Under 2025-03-26 the reply to a run tool call
# has as its `result` the runner's answer less every `structuredContent`
# member, keeping every other member, in order; so it has no
# `structuredContent`, and `result.json`'s text block still carries the
# value. Under 2025-06-18 and 2025-11-25 it is the runner's answer
# (laws/ToolResultsHoldContent.bend)
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server

# LAW: under 2025-03-26 the reply to a tool call has no structuredContent
law ran_unstructured:
  for id: Value.Json
  for result: Value.Json
  {Json.has(Json.get(Server.ran("2025-03-26", id, Rpc.Ok{result}), "result"),
    "structuredContent") == False{} : Bool}

# LAW: and its result is the runner's, less structuredContent
law ran_old_result:
  for id: Value.Json
  for result: Value.Json
  {Json.get(Server.ran("2025-03-26", id, Rpc.Ok{result}), "result")
    == Server.without(result, "structuredContent") : Value.Json}

# LAW: leaving a member out keeps every member with another key, in order
law without_keeps:
  for +k: String
  for v: Value.Json
  for r: Value.Json
  for +key: String
  for e: {Value.find.eq(k, key) == False{} : Bool}
  {Server.without.go(Value.JPair{k, v, r}, key)
    == Value.JPair{k, v, Server.without.go(r, key)} : Value.Json}

# LAW: and drops one with that key
law without_drops:
  for +k: String
  for v: Value.Json
  for r: Value.Json
  for +key: String
  for e: {Value.find.eq(k, key) == True{} : Bool}
  {Server.without.go(Value.JPair{k, v, r}, key) == Server.without.go(r, key)
    : Value.Json}

# LAW: a parsed member with another key is kept too
law without_keeps_bind:
  for +src: String
  for +num: U32
  for v: Value.Json
  for r: Value.Json
  for +key: String
  for e: {Value.span.eq(src, num, key) == False{} : Bool}
  {Server.without.go(Value.JBind{src, num, v, r}, key)
    == Value.JBind{src, num, v, Server.without.go(r, key)} : Value.Json}
