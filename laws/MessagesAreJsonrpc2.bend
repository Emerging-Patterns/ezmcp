# JSON-RPC §4 and §5: `jsonrpc` "**MUST** be exactly "2.0"". Every reply,
# request and notification ezmcp builds has `jsonrpc` `"2.0"`, and an
# incoming object whose `jsonrpc` is anything else is an invalid request,
# whose error carries the message's id when it has a valid one and null
# otherwise
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/rpc.bend as Rpc

# LAW: every reply says jsonrpc "2.0"
law reply_v2:
  for id: Value.Json
  for out: Rpc.Out
  {Json.get(Rpc.reply(id, out), "jsonrpc") == Json.str("2.0") : Value.Json}

# LAW: every request says jsonrpc "2.0"
law request_v2:
  for id: Value.Json
  for m: String
  for params: Value.Json
  {Json.get(Rpc.request(id, m, params), "jsonrpc") == Json.str("2.0")
    : Value.Json}

# LAW: every notification says jsonrpc "2.0"
law notice_v2:
  for m: String
  for params: Value.Json
  {Json.get(Rpc.notice(m, params), "jsonrpc") == Json.str("2.0") : Value.Json}

# LAW: an object whose jsonrpc is not "2.0" is an invalid request
law not_v2_junk:
  for has_id: Bool
  for ok: Bool
  for id: Value.Json
  for m: Maybe<&2, String>
  for params: Value.Json
  for r: Bool
  for e: Bool
  {Rpc.decide(Rpc.Head{True{}, False{}, has_id, ok, id, m, params, r, e})
    == Rpc.Junk{Rpc.head.id(has_id, ok, id),
      "Invalid Request: jsonrpc must be \"2.0\""} : Rpc.Msg}
