# `basic#responses`: "Responses **MUST** include the same ID as the request
# they correspond to." For every request and every way its method ends, what
# the server sends back carries the request's id: a reply's `id` member is
# the id it was built with, and a tool call to run carries the id into the
# reply built from its result
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server

# --- the specification's own words ---

# the id a server's act sends back: a reply's id, a tool call's id; null
# for no reply or a batch
def sent.id(lead: Server.Act) -> Value.Json:
  match lead:
    case Server.Quiet{}:
      Json.null()
    case Server.Send{reply}:
      Json.get(reply, "id")
    case Server.Fault{reply}:
      Json.get(reply, "id")
    case Server.Run{id, name, args}:
      id
    case Server.Batch{acts}:
      Json.null()

# LAW: a reply carries the id it was given
law reply_id:
  for id: Value.Json
  for out: Rpc.Out
  {Json.get(Rpc.reply(id, out), "id") == id : Value.Json}

# LAW: whatever a request's method does, what the server sends back carries
# the request's id
law answer_id:
  for id: Value.Json
  for s: Server.Step
  {sent.id(Server.answer(id, s)) == id : Value.Json}

# LAW: a tool's reply carries the call's id, whether the runner answered a
# result or refused
law ran_id:
  for rev: String
  for id: Value.Json
  for out: Rpc.Out
  {Json.get(Server.ran(rev, id, out), "id") == id : Value.Json}
