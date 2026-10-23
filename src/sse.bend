# ezmcp/src/sse: the data of a text/event-stream body, as an MCP client
# reads a POST's reply when the server streams it
# (basic/transports#sending-messages-to-the-server). Only `data:` fields
# are read: an event's data is its data lines joined by newlines, and the
# reply is the data of the last event that has any.
import Base

# while reading: the current event's data so far (if it has any), and the
# data of the last event that ended
type Sse is Data:
  Sse{cur: Maybe<&2, String>, last: String}

# one char of a line: a `\r` that ends the line is dropped
def unr.at(head: Char, rest: Unit -> String, ends: Bool) -> String:
  match ends:
    case True{}:
      ""
    case False{}:
      SCon{head, rest(Unit{})}

# a line's text with one `\r` at its end dropped
def unr(text: String) -> String:
  match text:
    case SNil{}:
      SNil{}
    case SCon{+head, +tail}:
      unr.at(head, _u => unr(tail),
        Bool.and(Char.is_eq(head, '\r'), String.is_empty(tail)))

# a data field's value: the text after `data:`, less one space
def value(text: String) -> String:
  match text:
    case SNil{}:
      SNil{}
    case SCon{+h, +t}:
      Bool.pick(String, Char.is_eq(h, ' '), t, SCon{h, t})

# more data for the current event
def more(cur: Maybe<&2, String>, val: String) -> Maybe<&2, String>:
  match cur:
    case None{}:
      Some{val}
    case Some{d}:
      Some{d ++ "\n" ++ val}

# the end of an event: its data, if any, is the latest
def end(cur: Maybe<&2, String>, last: String) -> Sse:
  match cur:
    case None{}:
      Sse{None{}, last}
    case Some{d}:
      Sse{None{}, d}

def line.data(
  cur: Maybe<&2, String>,
  last: String,
  +line: String,
  data: Bool
) -> Sse:
  match data:
    case True{}:
      Sse{more(cur, value(String.drop(line, 5n))), last}
    case False{}:
      Sse{cur, last}

def line.of(
  cur: Maybe<&2, String>,
  last: String,
  +line: String,
  blank: Bool
) -> Sse:
  match blank:
    case True{}:
      end(cur, last)
    case False{}:
      line.data(cur, last, line, String.starts_with(line, "data:"))

# one line of the stream
def line(text: Sse, +line2: String) -> Sse:
  match text:
    case Sse{cur, last}:
      line.of(cur, last, line2, String.is_empty(line2))

# every line of the stream, in order
def lines(ls: List<&2, String>, text: Sse) -> Sse:
  match ls:
    case []:
      text
    case l <> rest:
      lines(rest, line(text, unr(l)))

# the data the stream ends with: an unfinished event's, else the last one's
def fin(text: Sse) -> String:
  match text:
    case Sse{cur, last}:
      Maybe.default(&2, String, cur, last)

# the data of the last event that has any; an event the stream cut off
# before its blank line still counts
def last(body: String) -> String:
  fin(lines(String.lines(body), Sse{None{}, ""}))
