# `basic/transports`: "JSON-RPC messages **MUST** be UTF-8 encoded." A line
# is decoded from UTF-8 one sequence at a time: a byte below 0x80 is its
# char; a lead 0xC2 to 0xDF, 0xE0 to 0xEF or 0xF0 to 0xF4 with one, two or
# three continuation bytes (0x80 to 0xBF) is the char they encode; any other
# byte, and a lead whose continuation bytes are not all there, is U+FFFD and
# the decoding goes on at the next byte. A line is read whole before it is
# decoded, so a sequence cut between two reads is never misread
#
# Pending: proved is one decoding step for every lead byte and
# continuation (`Line.decode.step`), and that a line is decoded whole before
# it is judged. Left to prove: that `Line.decode`'s fuel, the line's length,
# never runs out before its bytes do, so the whole line is the steps above
# one after another.
import Base
import ../src/server.bend as Server
import ../src/line.bend as Line

# LAW: an ASCII byte is its own char
law utf8_one:
  for b: U32
  for t: List<&2, U32>
  for go: List<&2, U32> -> String
  for e: {U32.is_lt(b, 128) == True{} : Bool}
  {Line.decode.step(b <> t, go) == SCon{Chr{b}, go(t)} : String}

# LAW: a two-byte lead and a continuation byte are one char
law utf8_two:
  for a: U32
  for b: U32
  for t: List<&2, U32>
  for go: List<&2, U32> -> String
  for w: {Line.width(a) == Line.W2{} : Line.Width}
  for c: {Line.cont(b) == True{} : Bool}
  {Line.decode.step(a <> b <> t, go) == SCon{Chr{Line.two(a, b)}, go(t)}
    : String}

# LAW: a three-byte lead and two continuation bytes are one char
law utf8_three:
  for a: U32
  for b: U32
  for c: U32
  for t: List<&2, U32>
  for go: List<&2, U32> -> String
  for w: {Line.width(a) == Line.W3{} : Line.Width}
  for k: {Bool.and(Line.cont(b), Line.cont(c)) == True{} : Bool}
  {Line.decode.step(a <> b <> c <> t, go)
    == SCon{Chr{Line.three(a, b, c)}, go(t)} : String}

# LAW: a four-byte lead and three continuation bytes are one char
law utf8_four:
  for a: U32
  for b: U32
  for c: U32
  for d: U32
  for t: List<&2, U32>
  for go: List<&2, U32> -> String
  for w: {Line.width(a) == Line.W4{} : Line.Width}
  for k: {Bool.and(Line.cont(b), Bool.and(Line.cont(c), Line.cont(d))) == True{}
    : Bool}
  {Line.decode.step(a <> b <> c <> d <> t, go)
    == SCon{Chr{Line.four(a, b, c, d)}, go(t)} : String}

# LAW: a byte that starts no sequence is U+FFFD, and decoding goes on after it
law utf8_bad_lead:
  for a: U32
  for t: List<&2, U32>
  for go: List<&2, U32> -> String
  for w: {Line.width(a) == Line.W0{} : Line.Width}
  {Line.decode.step(a <> t, go) == SCon{Line.bad(), go(t)} : String}

# LAW: a lead whose continuation byte is bad is U+FFFD, and decoding goes on
# at that byte
law utf8_bad_cont:
  for a: U32
  for b: U32
  for t: List<&2, U32>
  for go: List<&2, U32> -> String
  for w: {Line.width(a) == Line.W2{} : Line.Width}
  for c: {Line.cont(b) == False{} : Bool}
  {Line.decode.step(a <> b <> t, go) == SCon{Line.bad(), go(b <> t)} : String}

# LAW: a line is read whole, decoded from UTF-8, then judged as text
law line_decoded:
  for srv: Server.Server
  for rev: String
  for bs: List<&2, U32>
  {Line.line(srv, rev, bs) == Line.line.text(srv, rev, Line.decode(bs))
    : Server.Turn}
