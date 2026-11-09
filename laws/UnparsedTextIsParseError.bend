# JSON-RPC §5.1: -32700 Parse error, "Invalid JSON was received by the
# server"; §5: the id "**MUST** be Null" when it could not be detected. For
# every text that does not parse as JSON, a server's act is a fault whose
# reply is error -32700 `Parse error` with a null id. Whether a text parses
# as JSON is ezjson's `parse` (ezjson's laws/ParsesExactlyJsonTexts.bend)
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server

# LAW: text that is not JSON is a parse error with a null id
law parse_error:
  for srv: Server.Server
  for rev: String
  for text: String
  for e: {Json.parse(text) == None{} : Maybe<&2, Value.Json>}
  {Server.step(srv, rev, text)
    == Server.Fault{Rpc.reply(Json.null(),
      Rpc.Err{Rpc.ParseError{}, "Parse error"})} : Server.Act}
