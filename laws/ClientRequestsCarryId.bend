# The client side builds requests and reads their replies; `src/io.bend`
# POSTs them to an endpoint over ezhttp. It speaks streamable HTTP only.
#
# `basic#requests` and `basic#notifications`: requests carry an id,
# "Notifications **MUST NOT** include an ID." Every request ezmcp builds
# carries exactly the id it was given; every notification has no `id`
# member; `client.call` is the `tools/call` request with the tool's `name`
# and the `arguments`, and `client.tools` the `tools/list` request with
# empty params
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/client.bend as Client

# LAW: a request carries its id
law request_id:
  for id: Value.Json
  for m: String
  for params: Value.Json
  {Json.get(Rpc.request(id, m, params), "id") == id : Value.Json}

# LAW: a notification carries no id
law notice_no_id:
  for m: String
  for params: Value.Json
  {Json.has(Rpc.notice(m, params), "id") == False{} : Bool}

# LAW: a tools/call request names the tool and passes the arguments
law call_request:
  for id: Value.Json
  for name: String
  for args: Value.Json
  {Client.call(id, name, args) == Rpc.request(id, "tools/call",
    Json.obj([("name", Json.str(name)), ("arguments", args)])) : Value.Json}

# LAW: a tools/list request has no params of its own
law tools_request:
  for id: Value.Json
  {Client.tools(id) == Rpc.request(id, "tools/list", Json.obj([]))
    : Value.Json}
