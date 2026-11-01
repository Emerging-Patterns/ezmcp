# proofs of laws/UnknownMethodsNotFound.bend
import Base
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server
import ../laws/UnknownMethodsNotFound.bend as Laws

def Laws.method_not_found(srv, m, params, e):
  f = Equal.sym(Server.Method, Server.method.of(m), Server.Other{}, e)
  %f : {Server.dispatch.of(srv, m, params, _)
    == Server.Now{Rpc.Err{Rpc.MethodNotFound{}, "Method not found: " ++ m}}
    : Server.Step}
  {==}

def Laws.ask_dispatch(_srv, _id, _m, _params):
  {==}
