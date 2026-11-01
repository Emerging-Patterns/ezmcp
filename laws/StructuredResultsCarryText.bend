# `server/tools#structured-content`: "a tool that returns structured content
# **SHOULD** also return the serialized JSON in a TextContent block."
# `result.json(v)` has `structuredContent` exactly `v`, and `content`
# exactly one text block holding `v`'s JSON text
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/server.bend as Server

# LAW: structured content is the value itself
law structured_value:
  for v: Value.Json
  for bad: Bool
  {Json.get(Server.structured(v, bad), "structuredContent") == v : Value.Json}

# LAW: and its content is one text block of the value's JSON text
law structured_text:
  for v: Value.Json
  for bad: Bool
  {Json.items(Json.get(Server.structured(v, bad), "content"))
    == [Server.text(Json.print(v))] : List<&2, Value.Json>}
