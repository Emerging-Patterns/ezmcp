# proofs of laws/LinesSplitAtNewlines.bend
import Base
import ../src/line.bend as Line
import ../laws/LinesSplitAtNewlines.bend as Laws
import ./lemmas/BoolCharStringFacts.bend as M1

# --- lists and Bool ---

def eq.and.left(
  u: Bool,
  v: Bool,
  e: {Bool.and(u, v) == True{} : Bool}
) -> {u == True{} : Bool}:
  match u:
    case True{}:
      {==}
    case False{}:
      e

def eq.and.right(
  u: Bool,
  v: Bool,
  e: {Bool.and(u, v) == True{} : Bool}
) -> {v == True{} : Bool}:
  match u:
    case True{}:
      e
    case False{}:
      M1.absurd(&2, {v == True{} : Bool}, e)

def eq.append_nil(
  xs: List<&2, U32>
) -> {List.append(&2, U32, xs, []) == xs : List<&2, U32>}:
  match xs:
    case []:
      {==}
    case h <> t:
      Equal.cong(List<&2, U32>, List<&2, U32>, r => h <> r,
        List.append(&2, U32, t, []), t, eq.append_nil(t))

def eq.append_assoc(
  xs: List<&2, U32>,
  ys: List<&2, U32>,
  zs: List<&2, U32>
) -> {List.append(&2, U32, List.append(&2, U32, xs, ys), zs)
  == List.append(&2, U32, xs, List.append(&2, U32, ys, zs)) : List<&2, U32>}:
  match xs:
    case []:
      {==}
    case h <> t:
      Equal.cong(List<&2, U32>, List<&2, U32>, r => h <> r,
        List.append(&2, U32, List.append(&2, U32, t, ys), zs),
        List.append(&2, U32, t, List.append(&2, U32, ys, zs)),
        eq.append_assoc(t, ys, zs))

# --- stdio lines ---

def split.flat_put(
  b: U32,
  ps: List<&2, List<&2, U32>>
) -> {Laws.flat(Line.split.put(b, ps)) == b <> Laws.flat(ps) : List<&2, U32>}:
  match ps:
    case []:
      {==}
    case p <> rest:
      {==}

def split.flat_at(
  b: U32,
  ps: List<&2, List<&2, U32>>,
  c: Bool
) -> {Laws.flat(Line.split.at(b, ps, c)) == b <> Laws.flat(ps) : List<&2, U32>}:
  match c:
    case True{}:
      {==}
    case False{}:
      split.flat_put(b, ps)

def split.ok_true(
  b: U32,
  ps: List<&2, List<&2, U32>>,
  e: {Line.nl(b) == True{} : Bool},
  h: {Laws.pieces.ok(ps) == True{} : Bool}
) -> {Laws.pieces.ok([b] <> ps) == True{} : Bool}:
  match ps:
    case []:
      M1.absurd(&2, {Laws.pieces.ok([[b]]) == True{} : Bool}, h)
    case q <> more:
      f = Equal.sym(Bool, Line.nl(b), True{}, e)
      %f : {Bool.and(_, Laws.pieces.ok.at(more, q)) == True{} : Bool}
      h

def split.ok_false.line(
  b: U32,
  p: List<&2, U32>,
  q: List<&2, U32>,
  more: List<&2, List<&2, U32>>,
  e: {Line.nl(b) == False{} : Bool},
  h: {Bool.and(Laws.line.ok(p), Laws.pieces.ok.at(more, q)) == True{} : Bool}
) -> {Bool.and(Laws.line.ok(b <> p), Laws.pieces.ok.at(more, q)) == True{} : Bool}:
  match p:
    case []:
      M1.absurd(&2, {Bool.and(Laws.line.ok([b]), Laws.pieces.ok.at(more, q))
        == True{} : Bool}, h)
    case c <> u:
      f = Equal.sym(Bool, Line.nl(b), False{}, e)
      %f : {Bool.and(Bool.and(Bool.not(_), Laws.line.ok.at(u, c)),
        Laws.pieces.ok.at(more, q)) == True{} : Bool}
      h

def split.ok_false.at(
  b: U32,
  p: List<&2, U32>,
  rest: List<&2, List<&2, U32>>,
  e: {Line.nl(b) == False{} : Bool},
  h: {Laws.pieces.ok.at(rest, p) == True{} : Bool}
) -> {Laws.pieces.ok.at(rest, b <> p) == True{} : Bool}:
  match rest:
    case []:
      f = Equal.sym(Bool, Line.nl(b), False{}, e)
      %f : {Bool.and(Bool.not(_), Laws.clean.one(p)) == True{} : Bool}
      h
    case q <> more:
      split.ok_false.line(b, p, q, more, e, h)

def split.ok_false(
  b: U32,
  ps: List<&2, List<&2, U32>>,
  e: {Line.nl(b) == False{} : Bool},
  h: {Laws.pieces.ok(ps) == True{} : Bool}
) -> {Laws.pieces.ok(Line.split.put(b, ps)) == True{} : Bool}:
  match ps:
    case []:
      M1.absurd(&2, {Laws.pieces.ok(Line.split.put(b, [])) == True{} : Bool}, h)
    case p <> rest:
      split.ok_false.at(b, p, rest, e, h)

def split.ok_at(
  b: U32,
  ps: List<&2, List<&2, U32>>,
  c: Bool,
  e: {Line.nl(b) == c : Bool},
  h: {Laws.pieces.ok(ps) == True{} : Bool}
) -> {Laws.pieces.ok(Line.split.at(b, ps, c)) == True{} : Bool}:
  match c:
    case True{}:
      split.ok_true(b, ps, e, h)
    case False{}:
      split.ok_false(b, ps, e, h)

def cut.glue_cons(
  p: List<&2, U32>,
  c: Line.Cut
) -> {Laws.glue(Line.cut.cons(p, c)) == List.append(&2, U32, p, Laws.glue(c)) : List<&2, U32>}:
  match c:
    case Line.Cut{ls, r}:
      eq.append_assoc(p, Laws.flat(ls), r)

def cut.glue_go(
  rest: List<&2, List<&2, U32>>,
  +p: List<&2, U32>
) -> {Laws.glue(Line.cut.go(rest, p)) == Laws.flat(p <> rest) : List<&2, U32>}:
  match rest:
    case []:
      Equal.sym(List<&2, U32>, List.append(&2, U32, p, []), p,
        eq.append_nil(p))
    case +q <> +more:
      Equal.trans(List<&2, U32>, Laws.glue(Line.cut.cons(p, Line.cut.go(more, q))),
        List.append(&2, U32, p, Laws.glue(Line.cut.go(more, q))),
        List.append(&2, U32, p, Laws.flat(q <> more)),
        cut.glue_cons(p, Line.cut.go(more, q)),
        Equal.cong(List<&2, U32>, List<&2, U32>, x => List.append(&2, U32, p, x),
          Laws.glue(Line.cut.go(more, q)), Laws.flat(q <> more),
          cut.glue_go(more, q)))

def cut.glue_of(
  ps: List<&2, List<&2, U32>>
) -> {Laws.glue(Line.cut.of(ps)) == Laws.flat(ps) : List<&2, U32>}:
  match ps:
    case []:
      {==}
    case p <> rest:
      cut.glue_go(rest, p)

def cut.lines_cons(
  p: List<&2, U32>,
  c: Line.Cut
) -> {Laws.cut.lines(Line.cut.cons(p, c)) == p <> Laws.cut.lines(c) : List<&2, List<&2, U32>>}:
  match c:
    case Line.Cut{ls, r}:
      {==}

def cut.rest_cons(
  p: List<&2, U32>,
  c: Line.Cut
) -> {Laws.cut.rest(Line.cut.cons(p, c)) == Laws.cut.rest(c) : List<&2, U32>}:
  match c:
    case Line.Cut{ls, r}:
      {==}

def cut.lines_go(
  rest: List<&2, List<&2, U32>>,
  +p: List<&2, U32>,
  +h: {Laws.pieces.ok.at(rest, p) == True{} : Bool}
) -> {Laws.lines.ok(Laws.cut.lines(Line.cut.go(rest, p))) == True{} : Bool}:
  match rest:
    case []:
      {==}
    case +q <> +more:
      l = Equal.sym(Bool, Laws.line.ok(p), True{},
        eq.and.left(Laws.line.ok(p), Laws.pieces.ok.at(more, q), h))
      r = cut.lines_go(more, q,
        eq.and.right(Laws.line.ok(p), Laws.pieces.ok.at(more, q), h))
      c = Equal.sym(List<&2, List<&2, U32>>,
        Laws.cut.lines(Line.cut.cons(p, Line.cut.go(more, q))),
        p <> Laws.cut.lines(Line.cut.go(more, q)),
        cut.lines_cons(p, Line.cut.go(more, q)))
      %c : {Laws.lines.ok(_) == True{} : Bool}
      %l : {Bool.and(_, Laws.lines.ok(Laws.cut.lines(Line.cut.go(more, q))))
        == True{} : Bool}
      r

def cut.rest_go(
  rest: List<&2, List<&2, U32>>,
  +p: List<&2, U32>,
  h: {Laws.pieces.ok.at(rest, p) == True{} : Bool}
) -> {Laws.clean.one(Laws.cut.rest(Line.cut.go(rest, p))) == True{} : Bool}:
  match rest:
    case []:
      h
    case +q <> +more:
      r = cut.rest_go(more, q,
        eq.and.right(Laws.line.ok(p), Laws.pieces.ok.at(more, q), h))
      c = Equal.sym(List<&2, U32>,
        Laws.cut.rest(Line.cut.cons(p, Line.cut.go(more, q))),
        Laws.cut.rest(Line.cut.go(more, q)),
        cut.rest_cons(p, Line.cut.go(more, q)))
      %c : {Laws.clean.one(_) == True{} : Bool}
      r

def cut.lines_of(
  ps: List<&2, List<&2, U32>>,
  h: {Laws.pieces.ok(ps) == True{} : Bool}
) -> {Laws.lines.ok(Laws.cut.lines(Line.cut.of(ps))) == True{} : Bool}:
  match ps:
    case []:
      {==}
    case p <> rest:
      cut.lines_go(rest, p, h)

def cut.rest_of(
  ps: List<&2, List<&2, U32>>,
  h: {Laws.pieces.ok(ps) == True{} : Bool}
) -> {Laws.clean.one(Laws.cut.rest(Line.cut.of(ps))) == True{} : Bool}:
  match ps:
    case []:
      {==}
    case p <> rest:
      cut.rest_go(rest, p, h)

def Laws.split_flat(bs):
  match bs:
    case []:
      {==}
    case +b <> +t:
      Equal.trans(List<&2, U32>, Laws.flat(Line.split.at(b, Line.split(t),
        Line.nl(b))), b <> Laws.flat(Line.split(t)), b <> t,
        split.flat_at(b, Line.split(t), Line.nl(b)),
        Equal.cong(List<&2, U32>, List<&2, U32>, r => b <> r,
          Laws.flat(Line.split(t)), t, Laws.split_flat(t)))

def Laws.split_pieces(bs):
  match bs:
    case []:
      {==}
    case +b <> +t:
      split.ok_at(b, Line.split(t), Line.nl(b), {==}, Laws.split_pieces(t))

def Laws.cut_glue(bs):
  Equal.trans(List<&2, U32>, Laws.glue(Line.cut.of(Line.split(bs))),
    Laws.flat(Line.split(bs)), bs, cut.glue_of(Line.split(bs)),
    Laws.split_flat(bs))

def Laws.cut_lines(bs):
  cut.lines_of(Line.split(bs), Laws.split_pieces(bs))

def Laws.cut_rest(bs):
  cut.rest_of(Line.split(bs), Laws.split_pieces(bs))
