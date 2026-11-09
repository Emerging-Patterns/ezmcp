# proofs of laws/KnownToolCallsRun.bend
import Base
import ezjson@1.2.0.0/main.bend as Json
import ../src/server.bend as Server
import ../laws/KnownToolCallsRun.bend as Laws
import ./lemmas/CompareSelfEqual.bend as M1

def Laws.call_dispatch(_srv, _params):
  {==}

def Laws.known_named(name, _description, _input, rest):
  f = Equal.sym(Bool, String.eq(name, name), True{}, M1.eq.string_self(name))
  %f : {Server.known.or(_, _u => Server.known(rest, name)) == True{} : Bool}
  {==}

def Laws.call_runs(name, params, has, obj):
  fh = Equal.sym(Bool, Json.has(params, "arguments"), True{}, has)
  fo = Equal.sym(Bool, Json.is_obj(Json.get(params, "arguments")), True{}, obj)
  %fh : {Server.call.args(name, _, Json.get(params, "arguments"))
    == Server.Call{name, Json.get(params, "arguments")} : Server.Step}
  %fo : {Bool.pick(Server.Step, _, Server.Call{name, Json.get(params,
    "arguments")}, Server.invalid("tools/call: arguments must be an object"))
    == Server.Call{name, Json.get(params, "arguments")} : Server.Step}
  {==}

def Laws.call_no_args(name, params, has):
  fh = Equal.sym(Bool, Json.has(params, "arguments"), False{}, has)
  %fh : {Server.call.args(name, _, Json.get(params, "arguments"))
    == Server.Call{name, Json.obj([])} : Server.Step}
  {==}

def Laws.call_named(_name, _description, _version, _instructions, tools, params, n, e):
  f = Equal.sym(Maybe<&2, String>, Json.as_str(Json.get(params, "name")),
    Some{n}, e)
  %f : {Server.call.named(tools, params, _)
    == Server.call.known(n, params, Server.known(tools, n)) : Server.Step}
  {==}

def Laws.call_is_run(_id, _name, _args):
  {==}
