# `basic/transports#stdio`: "The server **MUST NOT** write anything to its
# `stdout` that is not a valid MCP message." A line that is blank (empty or
# only whitespace, a lone `\r` included) is no message and gets nothing
# written; any other line is the server's turn on its text
# (laws/StreamKeepsNegotiatedRevision.bend), so what is written for it is a
# reply, a batch's array of replies, or nothing
# (laws/NotificationsGetNoReply.bend, laws/BatchesActInOrder.bend)
#
# also rests on: laws/LinesDecodedAsUtf8.bend
import Base
import ../src/server.bend as Server
import ../src/line.bend as Line

# LAW: a blank line is no message: nothing is written, and the revision is
# unchanged
law line_blank:
  for srv: Server.Server
  for rev: String
  for text: String
  for e: {String.is_empty(String.trim(text)) == True{} : Bool}
  {Line.line.text(srv, rev, text) == Server.Turn{Server.Quiet{}, rev}
    : Server.Turn}

# LAW: any other line is the server's turn on its text
law line_message:
  for srv: Server.Server
  for rev: String
  for text: String
  for e: {String.is_empty(String.trim(text)) == False{} : Bool}
  {Line.line.text(srv, rev, text) == Server.turn(srv, rev, text)
    : Server.Turn}
