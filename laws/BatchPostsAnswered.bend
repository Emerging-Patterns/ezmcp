# `2025-03-26/basic/transports#sending-messages-to-the-server`: the body may
# be "An array batching one or more requests and/or notifications"; "If the
# input consists solely of (any number of) JSON-RPC responses or
# notifications ... the server **MUST** return HTTP status code 202 Accepted
# with no body"; "If the input contains any number of JSON-RPC requests, the
# server **MUST** either return `Content-Type: text/event-stream` ... or
# `Content-Type: application/json`". A batch (laws/BatchesActInOrder.bend)
# is run under the request's revision before the reply; one that sends
# nothing back is answered 202 with no headers and no body, and any other
# 200 with `Content-Type: application/json` and the array of the replies as
# its body
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import 0xedb2120a04a47dc18c3a756ec7c62750/src/http.bend as Http
import ../src/server.bend as Server
import ../src/web.bend as Web

# LAW: a batch is run, under the request's revision, before the reply
law web_batch:
  for rev: String
  for acts: List<&2, Server.Act>
  {Web.act(rev, Server.Batch{acts}) == Web.Many{rev, acts} : Web.Web}

# LAW: a batch with no reply is accepted: 202, no body
law web_many_none:
  for replies: List<&2, Maybe<&2, Value.Json>>
  for e: {Server.batch.some(replies) == [] : List<&2, Value.Json>}
  {Web.many(Server.batch.reply(replies)) == Web.Now{202, [], ""} : Web.Web}

# LAW: else 200 with the array of the replies as one JSON body
law web_many_some:
  for batch: Value.Json
  {Web.many(Some{batch})
    == Web.Now{200, [Http.H{"Content-Type", "application/json"}],
      Json.print(batch)} : Web.Web}
