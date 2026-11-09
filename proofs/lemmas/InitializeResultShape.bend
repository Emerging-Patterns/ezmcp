# the initialize result, whatever the instructions
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ../../src/server.bend as Server

# an initialize result's members, with the instructions' emptiness as b
def init.of(
  version: String,
  caps: Value.Json,
  info: Value.Json,
  instructions: String,
  b: Bool
) -> Value.Json:
  Json.obj(List.append(&1, String & Value.Json,
    [("protocolVersion", Json.str(version)), ("capabilities", caps),
      ("serverInfo", info)], Server.init.extra(instructions, b)))
