# `basic#responses`: "Either a `result` or an `error` **MUST** be set. A
# response **MUST NOT** set both." A reply with jsonrpc `"2.0"` and only
# `result` is read as `Got` of its id and result; with only `error`, an
# integer code and a message, as `Refused` of its id, code and message; with
# both or neither, or not jsonrpc `"2.0"`, or not JSON, or with any HTTP
# status but 200, it is `Unread` with the reason
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/client.bend as Client

# LAW: a reply is judged by whether its status is 200
law took_status_200:
  for status: U32
  for ctype: String
  for text: String
  {Client.took(status, ctype, text)
    == Client.took.ok(ctype, text, U32.is_eq(status, 200), status)
    : Rpc.Reply}

# LAW: a reply with a result is read as that result
law read_got:
  for id: Value.Json
  for result: Value.Json
  for c: Maybe<&2, String>
  for m: Maybe<&2, String>
  {Rpc.back.decide(Rpc.Back{True{}, id, True{}, result, False{}, c, m})
    == Rpc.Got{id, result} : Rpc.Reply}

# LAW: a reply with an error is read as its code and message
law read_refused:
  for id: Value.Json
  for result: Value.Json
  for c: String
  for m: String
  {Rpc.back.decide(Rpc.Back{True{}, id, False{}, result, True{}, Some{c},
    Some{m}}) == Rpc.Refused{id, c, m} : Rpc.Reply}

# LAW: a reply with both or neither is unread
law read_both:
  for id: Value.Json
  for result: Value.Json
  for b: Bool
  for c: Maybe<&2, String>
  for m: Maybe<&2, String>
  {Rpc.back.decide(Rpc.Back{True{}, id, b, result, b, c, m})
    == Rpc.Unread{"a reply must hold exactly one of result and error"}
    : Rpc.Reply}

# LAW: a reply that is not JSON-RPC 2.0 is unread
law read_not_v2:
  for id: Value.Json
  for r: Bool
  for result: Value.Json
  for e: Bool
  for c: Maybe<&2, String>
  for m: Maybe<&2, String>
  {Rpc.back.decide(Rpc.Back{False{}, id, r, result, e, c, m})
    == Rpc.Unread{"not a JSON-RPC 2.0 reply"} : Rpc.Reply}

# LAW: a reply that is not JSON is unread
law read_not_json:
  for text: String
  for e: {Json.parse(text) == None{} : Maybe<&2, Value.Json>}
  {Rpc.read(text) == Rpc.Unread{"the reply is not JSON"} : Rpc.Reply}

# LAW: any status but 200 is unread, with the status and the body
law took_status:
  for ctype: String
  for text: String
  for status: U32
  {Client.took.ok(ctype, text, False{}, status)
    == Rpc.Unread{"HTTP " ++ U32.show(status) ++ ": " ++ text} : Rpc.Reply}
