# `basic#responses`, JSON-RPC §5: a response holds a valid id and "Either a
# `result` or an `error` **MUST** be set." An object with jsonrpc `"2.0"`,
# no method, a valid id and exactly one of `result` and `error` is a
# response, and a server's act on it is to send nothing (ezmcp sends no
# requests, so it awaits none)
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server

# LAW: a message with no method, a valid id and exactly one of result and
# error is a response
law response_is_answer:
  for id: Value.Json
  for params: Value.Json
  for r: Bool
  for e: Bool
  for one: {Rpc.one(r, e) == True{} : Bool}
  {Rpc.decide(Rpc.Head{True{}, True{}, True{}, True{}, id, None{}, params, r,
    e}) == Rpc.Answer{id} : Rpc.Msg}

# LAW: a response gets nothing back
law answer_is_quiet:
  for srv: Server.Server
  for id: Value.Json
  {Server.handle(srv, Rpc.Answer{id}) == Server.Quiet{} : Server.Act}
