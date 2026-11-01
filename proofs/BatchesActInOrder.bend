# proofs of laws/BatchesActInOrder.bend
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server
import ../laws/BatchesActInOrder.bend as Laws
import ./lemmas/ArrayItemsRoundTrip.bend as M1

def Laws.batches_oldest(_rev):
  {==}

def Laws.batch_turn(srv, items):
  f = Equal.sym(List<&2, Value.Json>, Value.items.go(Value.arr.go(items)),
    items, M1.eq.items_arr(items))
  %f : {Server.Turn{Server.batch(srv, _), "2025-03-26"}
    == Server.Turn{Server.batch(srv, items), "2025-03-26"} : Server.Turn}
  {==}

def Laws.batch_empty(_srv):
  {==}

def Laws.batch_acts(_srv, _i, _rest):
  {==}

def Laws.batch_all_each(_srv, _i, _rest):
  {==}

def Laws.batch_all_nil(_srv):
  {==}

def Laws.batch_init(_srv, _id, _params):
  {==}

def Laws.batch_ask(srv, id, m, params, e):
  f = Equal.sym(Bool, String.eq(m, "initialize"), False{}, e)
  %f : {Server.batch.init(id, Rpc.Ask{id, m, params}, _, srv)
    == Server.handle(srv, Rpc.Ask{id, m, params}) : Server.Act}
  {==}

def Laws.batch_tell(_srv, _m, _params):
  {==}

def Laws.batch_junk_one(_srv, _id, _why):
  {==}

def Laws.batch_reply_none(replies, e):
  f = Equal.sym(List<&2, Value.Json>, Server.batch.some(replies), [], e)
  %f : {Server.batch.gather(_) == None{} : Maybe<&2, Value.Json>}
  {==}

def Laws.batch_reply_some(replies, r, rest, e):
  f = Equal.sym(List<&2, Value.Json>, Server.batch.some(replies), r <> rest, e)
  %f : {Server.batch.gather(_) == Some{Json.arr(r <> rest)}
    : Maybe<&2, Value.Json>}
  {==}

def Laws.batch_some_skip(_rest):
  {==}

def Laws.batch_some_keep(_r, _rest):
  {==}
