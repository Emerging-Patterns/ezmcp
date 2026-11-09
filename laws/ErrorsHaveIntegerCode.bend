# `basic#responses`: "errors **MUST** include an error code and message at
# minimum. Error codes **MUST** be integers." Every error object ezmcp
# builds is exactly its code and its message, and every code is a number
# whose text is an integer (JSON-RPC §5.1's -32700, -32600, -32601, -32602,
# -32603)
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/rpc.bend as Rpc

# LAW: an error's code is a number whose text is an integer
law code_integer:
  for c: Rpc.Code
  {Rpc.int.text(Rpc.code.num(c)) == True{} : Bool}

# LAW: an error reply's error is its code and its message
law reply_err_fields:
  for id: Value.Json
  for c: Rpc.Code
  for message: String
  {Json.get(Rpc.reply(id, Rpc.Err{c, message}), "error")
    == Json.obj([("code", Json.num(Rpc.code.num(c))),
      ("message", Json.str(message))]) : Value.Json}
