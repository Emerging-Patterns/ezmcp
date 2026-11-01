# `basic#requests`: "Unlike base JSON-RPC, the ID **MUST NOT** be `null`."
# An object with a method and an `id` member that is not a valid id (null, a
# boolean, an array, an object, or a number that is not an integer) is an
# invalid request whose error carries a null id; it is never dispatched
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/rpc.bend as Rpc

# LAW: a value that is neither a string nor a number is no valid id: null,
# a boolean, an array, an object
law id_other:
  for v: Value.Json
  for es: {Json.as_str(v) == None{} : Maybe<&2, String>}
  for en: {Json.as_num(v) == None{} : Maybe<&2, String>}
  {Rpc.id.ok(v) == False{} : Bool}

# LAW: a message with a method and an id that is not valid is an invalid
# request, answered with a null id
law request_bad_id:
  for id: Value.Json
  for m: String
  for params: Value.Json
  for r: Bool
  for e: Bool
  {Rpc.decide(Rpc.Head{True{}, True{}, True{}, False{}, id, Some{m}, params,
    r, e})
    == Rpc.Junk{Json.null(), "Invalid Request: id must be a string or an integer"}
    : Rpc.Msg}
