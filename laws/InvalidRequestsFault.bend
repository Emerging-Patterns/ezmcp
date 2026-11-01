# JSON-RPC §5.1: -32600 Invalid Request, "The JSON sent is not a valid
# Request object"; the 2025-06-18 changelog: "Remove support for JSON-RPC
# batching". A value that is not an object (an array, which is a batch,
# included) is an invalid request with a null id; under a revision that
# receives no batches (2025-06-18, 2025-11-25) an array is therefore one
# invalid request, and leaves the revision as it was; an object with no
# method that is not a response is an invalid request; a server's act on any
# invalid request is a fault whose reply is error -32600 with the reason as
# its message and the message's id when valid, else null
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server

# LAW: a value that is not an object is an invalid request with a null id
law not_object_junk:
  for v2: Bool
  for has_id: Bool
  for ok: Bool
  for id: Value.Json
  for m: Maybe<&2, String>
  for params: Value.Json
  for r: Bool
  for e: Bool
  {Rpc.decide(Rpc.Head{False{}, v2, has_id, ok, id, m, params, r, e})
    == Rpc.Junk{Json.null(), "Invalid Request: not a JSON-RPC object"}
    : Rpc.Msg}

# LAW: an array (a batch, which 2025-06-18 removed) is an invalid request
law batch_junk:
  for items: List<&2, Value.Json>
  {Rpc.classify(Json.arr(items))
    == Rpc.Junk{Json.null(), "Invalid Request: not a JSON-RPC object"}
    : Rpc.Msg}

# LAW: under a revision that receives no batches, an array is one invalid
# request, a fault, and the revision is unchanged
law array_refused:
  for srv: Server.Server
  for +rev: String
  for items: List<&2, Value.Json>
  for e: {Server.batches(rev) == False{} : Bool}
  {Server.turn.parsed(srv, rev, Some{Json.arr(items)})
    == Server.Turn{Server.Fault{Rpc.reply(Json.null(),
      Rpc.Err{Rpc.InvalidRequest{}, "Invalid Request: not a JSON-RPC object"})},
      rev} : Server.Turn}

# LAW: a message with no method that is not a response is an invalid request
law no_method_junk:
  for has_id: Bool
  for ok: Bool
  for id: Value.Json
  for params: Value.Json
  for r: Bool
  for e: Bool
  for none: {Bool.and(Bool.and(has_id, ok), Rpc.one(r, e)) == False{} : Bool}
  {Rpc.decide(Rpc.Head{True{}, True{}, has_id, ok, id, None{}, params, r, e})
    == Rpc.Junk{Rpc.head.id(has_id, ok, id), "Invalid Request: no method"}
    : Rpc.Msg}

# LAW: an invalid request is a fault with code -32600
law junk_fault:
  for srv: Server.Server
  for id: Value.Json
  for why: String
  {Server.handle(srv, Rpc.Junk{id, why})
    == Server.Fault{Rpc.reply(id, Rpc.Err{Rpc.InvalidRequest{}, why})}
    : Server.Act}

# LAW: an invalid request's error carries its id only when it is valid
law junk_id:
  for has_id: Bool
  for ok: Bool
  for id: Value.Json
  {Rpc.head.id(has_id, ok, id)
    == Bool.pick(Value.Json, Bool.and(has_id, ok), id, Json.null())
    : Value.Json}
