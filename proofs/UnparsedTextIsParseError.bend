# proofs of laws/UnparsedTextIsParseError.bend
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server
import ../laws/UnparsedTextIsParseError.bend as Laws

def Laws.parse_error(srv, rev, text, e):
  f = Equal.sym(Maybe<&2, Value.Json>, Json.parse(text), None{}, e)
  %f : {Server.turn.act(Server.turn.parsed(srv, rev, _))
    == Server.Fault{Rpc.reply(Json.null(),
      Rpc.Err{Rpc.ParseError{}, "Parse error"})} : Server.Act}
  {==}
