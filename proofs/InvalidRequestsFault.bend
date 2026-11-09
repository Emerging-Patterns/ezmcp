# proofs of laws/InvalidRequestsFault.bend
import Base
import ezjson@1.2.0.0/main.bend as Json
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server
import ../laws/InvalidRequestsFault.bend as Laws

def Laws.not_object_junk(_v2, _has_id, _ok, _id, _m, _params, _r, _e):
  {==}

def Laws.batch_junk(_items):
  {==}

def Laws.no_method_junk(has_id, ok, id, _params, r, e, none):
  f = Equal.sym(Bool, Bool.and(Bool.and(has_id, ok), Rpc.one(r, e)), False{},
    none)
  %f : {Bool.pick(Rpc.Msg, _, Rpc.Answer{id},
    Rpc.Junk{Rpc.head.id(has_id, ok, id), "Invalid Request: no method"})
    == Rpc.Junk{Rpc.head.id(has_id, ok, id), "Invalid Request: no method"}
    : Rpc.Msg}
  {==}

def Laws.junk_fault(_srv, _id, _why):
  {==}

def Laws.junk_id(_has_id, _ok, _id):
  {==}

def Laws.array_refused(srv, rev, items, e):
  f = Equal.sym(Bool, Server.batches(rev), False{}, e)
  %f : {Server.turn.value(srv, rev, Json.arr(items), _)
    == Server.Turn{Server.Fault{Rpc.reply(Json.null(),
      Rpc.Err{Rpc.InvalidRequest{}, "Invalid Request: not a JSON-RPC object"})},
      rev} : Server.Turn}
  {==}
