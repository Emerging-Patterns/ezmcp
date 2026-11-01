# `basic/transports#stdio`. stdin is read as bytes, a chunk at a time;
# `Line.cut` splits what has been read into whole lines and a rest, which
# waits for the next chunk; each whole line is decoded from UTF-8 and is one
# message. When stdin ends, the rest is the last message.
#
# `basic/transports#stdio`: "Messages are delimited by newlines, and **MUST
# NOT** contain embedded newlines." For every buffer, the cut's lines and
# rest are the buffer's bytes in order; every line it hands on ends with its
# newline and holds no other; and the rest it keeps holds no newline. So
# every message is exactly the bytes between two newlines
import Base
import ../src/line.bend as Line

# whether bytes hold no newline
def clean.one(piece: List<&2, U32>) -> Bool:
  match piece:
    case []:
      True{}
    case +b <> t:
      Bool.and(Bool.not(Line.nl(b)), clean.one(t))

def line.ok.at(tail: List<&2, U32>, +byte: U32) -> Bool:
  match tail:
    case []:
      Line.nl(byte)
    case c <> u:
      Bool.and(Bool.not(Line.nl(byte)), line.ok.at(u, c))

# whether bytes are one line: no newline but the last byte, which is one
def line.ok(piece: List<&2, U32>) -> Bool:
  match piece:
    case []:
      False{}
    case +b <> t:
      line.ok.at(t, b)

def pieces.ok.at(rest: List<&2, List<&2, U32>>, piece: List<&2, U32>) -> Bool:
  match rest:
    case []:
      clean.one(piece)
    case q <> more:
      Bool.and(line.ok(piece), pieces.ok.at(more, q))

# whether pieces are lines, then a last piece with no newline
def pieces.ok(ps: List<&2, List<&2, U32>>) -> Bool:
  match ps:
    case []:
      False{}
    case p <> rest:
      pieces.ok.at(rest, p)

# whether every piece is a line
def lines.ok(ps: List<&2, List<&2, U32>>) -> Bool:
  match ps:
    case []:
      True{}
    case p <> rest:
      Bool.and(line.ok(p), lines.ok(rest))

# pieces' bytes, one after another
def flat(ps: List<&2, List<&2, U32>>) -> List<&2, U32>:
  match ps:
    case []:
      []
    case p <> rest:
      List.append(&2, U32, p, flat(rest))

# the bytes a cut came from: its lines, then its rest
def glue(cb: Line.Cut) -> List<&2, U32>:
  match cb:
    case Line.Cut{lines, rest}:
      List.append(&2, U32, flat(lines), rest)

# a cut's lines
def cut.lines(cb: Line.Cut) -> List<&2, List<&2, U32>>:
  match cb:
    case Line.Cut{lines, rest}:
      lines

# a cut's rest
def cut.rest(cb: Line.Cut) -> List<&2, U32>:
  match cb:
    case Line.Cut{lines, rest}:
      rest

# LAW: the pieces split after newlines are the bytes, in order
law split_flat:
  for +bs: List<&2, U32>
  {flat(Line.split(bs)) == bs : List<&2, U32>}

# LAW: the pieces are lines, then a last piece with no newline
law split_pieces:
  for +bs: List<&2, U32>
  {pieces.ok(Line.split(bs)) == True{} : Bool}

# LAW: a cut's lines and rest are the buffer, in order
law cut_glue:
  for +bs: List<&2, U32>
  {glue(Line.cut(bs)) == bs : List<&2, U32>}

# LAW: every line a cut hands on is one line: a newline at its end and none
# before it
law cut_lines:
  for +bs: List<&2, U32>
  {lines.ok(cut.lines(Line.cut(bs))) == True{} : Bool}

# LAW: what a cut keeps for the next read holds no newline
law cut_rest:
  for +bs: List<&2, U32>
  {clean.one(cut.rest(Line.cut(bs))) == True{} : Bool}
