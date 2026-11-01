# `basic/transports#sending-messages-to-the-server`: the server returns an
# event stream or one JSON object; "The client **MUST** support both these
# cases." A 200 reply whose `Content-Type` is `text/event-stream` is read
# from the data of its last event that has any, and any other 200 reply from
# its body. In a stream, a `data:` line adds its value, less one leading
# space, to the current event, an event's data lines are joined by newlines,
# and a blank line ends the event
#
# also rests on: laws/ClientReadsReplies.bend
import Base
import ../src/rpc.bend as Rpc
import ../src/sse.bend as Sse
import ../src/client.bend as Client

# LAW: a 200 reply is read as an event stream or as JSON by its type
law took_ok:
  for ctype: String
  for text: String
  for status: U32
  {Client.took.ok(ctype, text, True{}, status)
    == Rpc.read(Client.body(Client.is.sse(ctype), text)) : Rpc.Reply}

# LAW: an event stream's JSON text is its last data
law body_sse:
  for text: String
  {Client.body(True{}, text) == Sse.last(text) : String}

# LAW: any other body is the JSON text
law body_json:
  for text: String
  {Client.body(False{}, text) == text : String}

# LAW: a data line adds its value to the event, less one space
law sse_data:
  for cur: Maybe<&2, String>
  for last: String
  for x: String
  {Sse.line(Sse.Sse{cur, last}, "data: " ++ x)
    == Sse.Sse{Sse.more(cur, x), last} : Sse.Sse}

# LAW: a blank line ends an event, whose data, if any, is the latest
law sse_end:
  for d: String
  for last: String
  {Sse.line(Sse.Sse{Some{d}, last}, "") == Sse.Sse{None{}, d} : Sse.Sse}

# LAW: an event's data lines are joined by newlines
law sse_more:
  for d: String
  for x: String
  {Sse.more(Some{d}, x) == Some{d ++ "\n" ++ x} : Maybe<&2, String>}
