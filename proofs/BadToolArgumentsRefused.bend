# proofs of laws/BadToolArgumentsRefused.bend
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server
import ../laws/BadToolArgumentsRefused.bend as Laws

def Laws.call_no_name(srv, params, e):
  match srv:
    case Server.Server{name, version, instructions, tools}:
      f = Equal.sym(Maybe<&2, String>, Json.as_str(Json.get(params, "name")),
        None{}, e)
      %f : {Server.call.named(tools, params, _)
        == Server.Now{Rpc.Err{Rpc.InvalidParams{},
          "tools/call: params.name must be a string"}} : Server.Step}
      {==}

def Laws.call_bad_args(name, params, has, obj):
  fh = Equal.sym(Bool, Json.has(params, "arguments"), True{}, has)
  fo = Equal.sym(Bool, Json.is_obj(Json.get(params, "arguments")), False{}, obj)
  %fh : {Server.call.args(name, _, Json.get(params, "arguments"))
    == Server.Now{Rpc.Err{Rpc.InvalidParams{},
      "tools/call: arguments must be an object"}} : Server.Step}
  %fo : {Bool.pick(Server.Step, _, Server.Call{name, Json.get(params,
    "arguments")}, Server.invalid("tools/call: arguments must be an object"))
    == Server.Now{Rpc.Err{Rpc.InvalidParams{},
      "tools/call: arguments must be an object"}} : Server.Step}
  {==}
