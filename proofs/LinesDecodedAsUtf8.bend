# proofs of laws/LinesDecodedAsUtf8.bend
import Base
import ../src/line.bend as Line
import ../laws/LinesDecodedAsUtf8.bend as Laws

# --- UTF-8 lead bytes ---

def utf8.width_one(
  +b: U32,
  e: {U32.is_lt(b, 128) == True{} : Bool}
) -> {Line.width(b) == Line.W1{} : Line.Width}:
  f = Equal.sym(Bool, U32.is_lt(b, 128), True{}, e)
  %f : {Bool.pick(Line.Width, _, Line.W1{},
    Bool.pick(Line.Width, Bool.and(U32.is_ge(b, 194), U32.is_le(b, 223)),
      Line.W2{},
      Bool.pick(Line.Width, Bool.and(U32.is_ge(b, 224), U32.is_le(b, 239)),
        Line.W3{},
        Bool.pick(Line.Width, Bool.and(U32.is_ge(b, 240), U32.is_le(b, 244)),
          Line.W4{}, Line.W0{})))) == Line.W1{} : Line.Width}
  {==}

def Laws.utf8_one(b, t, go, e):
  g = Equal.sym(Line.Width, Line.width(b), Line.W1{}, utf8.width_one(b, e))
  %g : {Line.dec.lead(b, t, _, go) == SCon{Chr{b}, go(t)} : String}
  {==}

def Laws.utf8_two(a, b, t, go, w, c):
  g = Equal.sym(Line.Width, Line.width(a), Line.W2{}, w)
  f = Equal.sym(Bool, Line.cont(b), True{}, c)
  %g : {Line.dec.lead(a, b <> t, _, go) == SCon{Chr{Line.two(a, b)}, go(t)}
    : String}
  %f : {Line.dec.take(Chr{Line.two(a, b)}, _, b <> t, t, go)
    == SCon{Chr{Line.two(a, b)}, go(t)} : String}
  {==}

def Laws.utf8_three(a, b, c, t, go, w, k):
  g = Equal.sym(Line.Width, Line.width(a), Line.W3{}, w)
  f = Equal.sym(Bool, Bool.and(Line.cont(b), Line.cont(c)), True{}, k)
  %g : {Line.dec.lead(a, b <> c <> t, _, go)
    == SCon{Chr{Line.three(a, b, c)}, go(t)} : String}
  %f : {Line.dec.take(Chr{Line.three(a, b, c)}, _, b <> c <> t, t, go)
    == SCon{Chr{Line.three(a, b, c)}, go(t)} : String}
  {==}

def Laws.utf8_four(a, b, c, d, t, go, w, k):
  g = Equal.sym(Line.Width, Line.width(a), Line.W4{}, w)
  f = Equal.sym(Bool, Bool.and(Line.cont(b), Bool.and(Line.cont(c),
    Line.cont(d))), True{}, k)
  %g : {Line.dec.lead(a, b <> c <> d <> t, _, go)
    == SCon{Chr{Line.four(a, b, c, d)}, go(t)} : String}
  %f : {Line.dec.take(Chr{Line.four(a, b, c, d)}, _, b <> c <> d <> t, t, go)
    == SCon{Chr{Line.four(a, b, c, d)}, go(t)} : String}
  {==}

def Laws.utf8_bad_lead(a, t, go, w):
  g = Equal.sym(Line.Width, Line.width(a), Line.W0{}, w)
  %g : {Line.dec.lead(a, t, _, go) == SCon{Line.bad(), go(t)} : String}
  {==}

def Laws.utf8_bad_cont(a, b, t, go, w, c):
  g = Equal.sym(Line.Width, Line.width(a), Line.W2{}, w)
  f = Equal.sym(Bool, Line.cont(b), False{}, c)
  %g : {Line.dec.lead(a, b <> t, _, go) == SCon{Line.bad(), go(b <> t)}
    : String}
  %f : {Line.dec.take(Chr{Line.two(a, b)}, _, b <> t, t, go)
    == SCon{Line.bad(), go(b <> t)} : String}
  {==}

def Laws.line_decoded(_srv, _rev, _bs):
  {==}
