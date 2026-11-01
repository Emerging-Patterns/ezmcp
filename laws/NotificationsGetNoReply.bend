# `basic#notifications`, JSON-RPC §4.1: "Notifications **MUST NOT** include
# an ID", and "The receiver **MUST NOT** send a response." An object with
# jsonrpc `"2.0"`, a method and no `id` member is a notification, and a
# server's act on any notification is to send nothing
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server

# LAW: a message with a method and no id is a notification
law notification_is_tell:
  for ok: Bool
  for id: Value.Json
  for m: String
  for params: Value.Json
  for r: Bool
  for e: Bool
  {Rpc.decide(Rpc.Head{True{}, True{}, False{}, ok, id, Some{m}, params, r,
    e}) == Rpc.Tell{m, params} : Rpc.Msg}

# LAW: a notification gets nothing back
law tell_is_quiet:
  for srv: Server.Server
  for m: String
  for params: Value.Json
  {Server.handle(srv, Rpc.Tell{m, params}) == Server.Quiet{} : Server.Act}
