# `basic#messages`: "All messages between MCP clients and servers **MUST**
# follow the JSON-RPC 2.0 specification." `Rpc.classify` reads one decoded
# value as a request (`Ask`), a notification (`Tell`), a response (`Answer`)
# or an invalid request (`Junk`), through `Rpc.decide` over the fields it
# looks at (`Rpc.Head`); `Server.handle` acts on it.
#
# `basic#requests`, JSON-RPC §4: "Requests **MUST** include a string or
# integer ID." An object whose `jsonrpc` is `"2.0"`, whose `method` is a
# string and whose `id` is a string, or a number whose text is an integer
# (an optional `-`, then digits), is a request with exactly that id, method
# and params, whatever else it holds
import Base
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/rpc.bend as Rpc

# LAW: an object with jsonrpc "2.0", a method and a valid id is a request
# with that id, method and params
law request_is_ask:
  for id: Value.Json
  for m: String
  for params: Value.Json
  for r: Bool
  for e: Bool
  {Rpc.decide(Rpc.Head{True{}, True{}, True{}, True{}, id, Some{m}, params, r,
    e}) == Rpc.Ask{id, m, params} : Rpc.Msg}

# LAW: every string is a valid id
law id_string:
  for s: String
  {Rpc.id.ok(Value.JStr{s}) == True{} : Bool}

# LAW: a number is a valid id exactly when its text is an integer
law id_number:
  for raw: String
  {Rpc.id.ok(Value.JNum{raw}) == Rpc.int.text(raw) : Bool}

# LAW: an integer's text may open with a minus, then digits
law int_minus:
  for t: String
  {Rpc.int.text(SCon{'-', t}) == Rpc.digits(t) : Bool}

# LAW: any other integer's text is digits only
law int_digits:
  for h: Char
  for t: String
  for e: {Char.is_eq(h, '-') == False{} : Bool}
  {Rpc.int.text(SCon{h, t}) == Rpc.digits(SCon{h, t}) : Bool}
