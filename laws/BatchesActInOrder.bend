# `2025-03-26/basic#batching`: "MCP implementations **MAY** support sending
# JSON-RPC batches, but **MUST** support receiving JSON-RPC batches";
# `2025-03-26/basic/lifecycle#initialization`: "The initialize request
# **MUST NOT** be part of a JSON-RPC batch"; JSON-RPC §6: an empty array is
# answered with a single Invalid Request, and "If there are no Response
# objects contained within the Response array as it is to be sent to the
# client, the server **MUST NOT** return an empty Array and should return
# nothing at all." Only 2025-03-26 receives batches. Under it, an array of
# one or more values is a batch whose acts are one per element, in order:
# each element's act as it would be alone, except that an `initialize`
# request is an invalid request (-32600) with its id; an empty array is one
# invalid request with a null id; a batch leaves the revision as it was. A
# batch sends back nothing when no element has a reply, and else the array
# of the replies in order
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server

# LAW: only 2025-03-26 receives batches
law batches_oldest:
  for rev: String
  {Server.batches(rev) == String.eq(rev, "2025-03-26") : Bool}

# LAW: under 2025-03-26 an array is a batch, and the revision is unchanged
law batch_turn:
  for srv: Server.Server
  for items: List<&2, Value.Json>
  {Server.turn.parsed(srv, "2025-03-26", Some{Json.arr(items)})
    == Server.Turn{Server.batch(srv, items), "2025-03-26"} : Server.Turn}

# LAW: an empty batch is one invalid request, with a null id
law batch_empty:
  for srv: Server.Server
  {Server.batch(srv, [])
    == Server.Fault{Rpc.reply(Json.null(), Rpc.Err{Rpc.InvalidRequest{},
      "Invalid Request: empty batch"})} : Server.Act}

# LAW: any other batch is its elements' acts
law batch_acts:
  for srv: Server.Server
  for i: Value.Json
  for rest: List<&2, Value.Json>
  {Server.batch(srv, i <> rest) == Server.Batch{Server.batch.all(srv, i <> rest)}
    : Server.Act}

# LAW: a batch's acts are one per element, in order
law batch_all_each:
  for srv: Server.Server
  for i: Value.Json
  for rest: List<&2, Value.Json>
  {Server.batch.all(srv, i <> rest)
    == Server.batch.one(srv, Rpc.classify(i)) <> Server.batch.all(srv, rest)
    : List<&2, Server.Act>}

# LAW: and none past the last element
law batch_all_nil:
  for srv: Server.Server
  {Server.batch.all(srv, []) == [] : List<&2, Server.Act>}

# LAW: an initialize in a batch is an invalid request with its id
law batch_init:
  for srv: Server.Server
  for id: Value.Json
  for params: Value.Json
  {Server.batch.one(srv, Rpc.Ask{id, "initialize", params})
    == Server.Send{Rpc.reply(id, Rpc.Err{Rpc.InvalidRequest{},
      "Invalid Request: initialize must not be part of a batch"})}
    : Server.Act}

# LAW: any other request in a batch is answered as it would be alone
law batch_ask:
  for srv: Server.Server
  for id: Value.Json
  for +m: String
  for params: Value.Json
  for e: {String.eq(m, "initialize") == False{} : Bool}
  {Server.batch.one(srv, Rpc.Ask{id, m, params})
    == Server.handle(srv, Rpc.Ask{id, m, params}) : Server.Act}

# LAW: a notification in a batch gets nothing back
law batch_tell:
  for srv: Server.Server
  for m: String
  for params: Value.Json
  {Server.batch.one(srv, Rpc.Tell{m, params}) == Server.Quiet{} : Server.Act}

# LAW: an element that is not a valid message is an invalid request, as it
# would be alone
law batch_junk_one:
  for srv: Server.Server
  for id: Value.Json
  for why: String
  {Server.batch.one(srv, Rpc.Junk{id, why})
    == Server.handle(srv, Rpc.Junk{id, why}) : Server.Act}

# LAW: a batch sends back nothing when no element has a reply
law batch_reply_none:
  for replies: List<&2, Maybe<&2, Value.Json>>
  for e: {Server.batch.some(replies) == [] : List<&2, Value.Json>}
  {Server.batch.reply(replies) == None{} : Maybe<&2, Value.Json>}

# LAW: else the array of the replies
law batch_reply_some:
  for replies: List<&2, Maybe<&2, Value.Json>>
  for r: Value.Json
  for rest: List<&2, Value.Json>
  for e: {Server.batch.some(replies) == r <> rest : List<&2, Value.Json>}
  {Server.batch.reply(replies) == Some{Json.arr(r <> rest)}
    : Maybe<&2, Value.Json>}

# LAW: the replies are the elements' that have one, in order
law batch_some_skip:
  for rest: List<&2, Maybe<&2, Value.Json>>
  {Server.batch.some(None{} <> rest) == Server.batch.some(rest)
    : List<&2, Value.Json>}

# LAW: an element's reply comes before the rest's
law batch_some_keep:
  for r: Value.Json
  for rest: List<&2, Maybe<&2, Value.Json>>
  {Server.batch.some(Some{r} <> rest) == r <> Server.batch.some(rest)
    : List<&2, Value.Json>}
