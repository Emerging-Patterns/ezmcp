# `basic#responses`: "Either a `result` or an `error` **MUST** be set. A
# response **MUST NOT** set both." Every reply ezmcp builds has `result` and
# no `error` when it succeeds, and `error` and no `result` when it fails
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/rpc.bend as Rpc

# whether a value has a member and not another
def has.only(+val: Value.Json, yes: String, no: String) -> Bool:
  Bool.and(Json.has(val, yes), Bool.not(Json.has(val, no)))

# LAW: a successful reply has a result and no error
law reply_ok_one:
  for id: Value.Json
  for result: Value.Json
  {has.only(Rpc.reply(id, Rpc.Ok{result}), "result", "error") == True{}
    : Bool}

# LAW: an error reply has an error and no result
law reply_err_one:
  for id: Value.Json
  for c: Rpc.Code
  for message: String
  {has.only(Rpc.reply(id, Rpc.Err{c, message}), "error", "result") == True{}
    : Bool}
