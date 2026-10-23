# ezmcp/src/line: the stdio transport's decisions, with no IO
# (basic/transports#stdio). Bytes read from stdin are cut at each newline,
# each whole line is decoded from UTF-8 and is one message; a reply is its
# JSON text and one newline.
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ./server.bend as Server

# whole lines, each with its newline, and the bytes after the last newline
type Cut is Data:
  Cut{lines: List<&2, List<&2, U32>>, rest: List<&2, U32>}

# a byte is a newline
def nl(+byte: U32) -> Bool:
  U32.is_eq(byte, 10)

# put a byte at the front of the first piece
def split.put(byte: U32, ps: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match ps:
    case []:
      [[byte]]
    case p <> rest:
      (byte <> p) <> rest

# a newline ends a piece of its own, which the bytes before it join; any
# other byte joins the first piece
def split.at(
  byte: U32,
  ps: List<&2, List<&2, U32>>,
  cut: Bool
) -> List<&2, List<&2, U32>>:
  match cut:
    case True{}:
      [byte] <> ps
    case False{}:
      split.put(byte, ps)

# bytes split after every newline: each piece but the last ends with its
# newline, and the last has none
def split(bs: List<&2, U32>) -> List<&2, List<&2, U32>>:
  match bs:
    case []:
      [[]]
    case +b <> t:
      split.at(b, split(t), nl(b))

def cut.cons(piece: List<&2, U32>, cb: Cut) -> Cut:
  match cb:
    case Cut{lines, rest}:
      Cut{piece <> lines, rest}

def cut.go(rest: List<&2, List<&2, U32>>, piece: List<&2, U32>) -> Cut:
  match rest:
    case []:
      Cut{[], piece}
    case q <> more:
      cut.cons(piece, cut.go(more, q))

def cut.of(ps: List<&2, List<&2, U32>>) -> Cut:
  match ps:
    case []:
      Cut{[], []}
    case p <> rest:
      cut.go(rest, p)

# the whole lines in a buffer, and what follows the last newline
def cut(bs: List<&2, U32>) -> Cut:
  cut.of(split(bs))

# --- UTF-8 ---

# a byte is a continuation byte, 0x80 to 0xBF
def cont(+byte: U32) -> Bool:
  Bool.and(U32.is_ge(byte, 128), U32.is_le(byte, 191))

# U+FFFD, for a byte that starts no valid sequence
def bad() -> Char:
  Chr{65533}

# a continuation byte's six payload bits
def low6(+byte: U32) -> U32:
  U32.sub(byte, 128)

# the code point of a two-byte sequence
def two(+lead: U32, +byte: U32) -> U32:
  U32.add(U32.mul(U32.sub(lead, 192), 64), low6(byte))

# the code point of a three-byte sequence
def three(+lead: U32, +byte: U32, +cb: U32) -> U32:
  U32.add(U32.mul(U32.add(U32.mul(U32.sub(lead, 224), 64), low6(byte)), 64), low6(cb))

# the code point of a four-byte sequence
def four(+lead: U32, +byte: U32, +cb: U32, +db: U32) -> U32:
  U32.add(U32.mul(U32.add(U32.mul(U32.add(U32.mul(U32.sub(lead, 240), 64),
    low6(byte)), 64), low6(cb)), 64), low6(db))

# how many bytes a lead byte starts
type Width is Data:
  W0{}
  W1{}
  W2{}
  W3{}
  W4{}

# 1 for ASCII, 2 to 4 for a lead byte, 0 for a byte that starts nothing
def width(+byte: U32) -> Width:
  Bool.pick(Width, U32.is_lt(byte, 128), W1{},
    Bool.pick(Width, Bool.and(U32.is_ge(byte, 194), U32.is_le(byte, 223)), W2{},
      Bool.pick(Width, Bool.and(U32.is_ge(byte, 224), U32.is_le(byte, 239)), W3{},
        Bool.pick(Width, Bool.and(U32.is_ge(byte, 240), U32.is_le(byte, 244)), W4{},
          W0{}))))

# a sequence whose continuation bytes are all valid is its char, and the
# decoding goes on after it; else the lead byte is U+FFFD and the decoding
# goes on at the byte after it
def dec.take(
  ch: Char,
  ok: Bool,
  after_lead: List<&2, U32>,
  after_seq: List<&2, U32>,
  go: List<&2, U32> -> String
) -> String:
  match ok:
    case True{}:
      SCon{ch, go(after_seq)}
    case False{}:
      SCon{bad(), go(after_lead)}

def dec.two(+lead: U32, bs: List<&2, U32>, go: List<&2, U32> -> String) -> String:
  match bs:
    case +b <> +t:
      dec.take(Chr{two(lead, b)}, cont(b), b <> t, t, go)
    case []:
      SCon{bad(), SNil{}}

def dec.three(
  +lead: U32,
  bs: List<&2, U32>,
  go: List<&2, U32> -> String
) -> String:
  match bs:
    case +b <> +c <> +t:
      dec.take(Chr{three(lead, b, c)}, Bool.and(cont(b), cont(c)), b <> c <> t,
        t, go)
    case other:
      SCon{bad(), go(other)}

def dec.four(+lead: U32, bs: List<&2, U32>, go: List<&2, U32> -> String) -> String:
  match bs:
    case +b <> +c <> +d <> +t:
      dec.take(Chr{four(lead, b, c, d)},
        Bool.and(cont(b), Bool.and(cont(c), cont(d))), b <> c <> d <> t, t, go)
    case other:
      SCon{bad(), go(other)}

# one sequence at a lead byte of width w, then `go` on what follows
def dec.lead(
  +byte: U32,
  tail: List<&2, U32>,
  wid: Width,
  go: List<&2, U32> -> String
) -> String:
  match wid:
    case W1{}:
      SCon{Chr{byte}, go(tail)}
    case W2{}:
      dec.two(byte, tail, go)
    case W3{}:
      dec.three(byte, tail, go)
    case W4{}:
      dec.four(byte, tail, go)
    case W0{}:
      SCon{bad(), go(tail)}

def decode.step(bs: List<&2, U32>, go: List<&2, U32> -> String) -> String:
  match bs:
    case []:
      SNil{}
    case +b <> t:
      dec.lead(b, t, width(b), go)

# decode with fuel: every step takes at least one byte, so a buffer's
# length is fuel enough
def decode.go(fuel: Nat, bs: List<&2, U32>) -> String:
  match fuel:
    case 0n:
      SNil{}
    case 1n+f:
      decode.step(bs, xs => decode.go(f, xs))

# bytes decoded from UTF-8; a byte that starts no valid sequence is U+FFFD
def decode(+bs: List<&2, U32>) -> String:
  decode.go(List.length(&2, U32, bs), bs)

# --- messages ---

def line.of(
  srv: Server.Server,
  +rev: String,
  +text: String,
  blank: Bool
) -> Server.Turn:
  match blank:
    case True{}:
      Server.Turn{Server.Quiet{}, rev}
    case False{}:
      Server.turn(srv, rev, text)

def line.text(srv: Server.Server, +rev: String, +text: String) -> Server.Turn:
  line.of(srv, rev, text, String.is_empty(String.trim(text)))

# what a server does with one line read by revision `rev`, and the revision
# the next line is read by: nothing for a blank one, and the revision
# unchanged; else the server's turn on its text
def line(srv: Server.Server, rev: String, bs: List<&2, U32>) -> Server.Turn:
  line.text(srv, rev, decode(bs))

# one message on stdout: its JSON text and a newline
def frame(val: Value.Json) -> String:
  Json.print(val) ++ "\n"
