# every Bool, Order, String, U32 and word compares equal to itself
import Base

def eq.bool_cmp_self(b: Bool) -> {Bool.cmp(b, b) == EQ{} : Cmp}:
  match b:
    case False{}:
      {==}
    case True{}:
      {==}

def eq.word_cmp_self(n: Nat, w: Word(n)) -> {Word.cmp(n, w, w) == EQ{} : Cmp}:
  match n:
    case 0n:
      match w:
        case WNil{}:
          {==}
    case 1n+p:
      match w:
        case WCon{+b, +t}:
          Equal.trans(Cmp, Word.cmp.fin(b, b, Word.cmp(p, t, t)),
            Word.cmp.fin(b, b, EQ{}), EQ{},
            Equal.cong(Cmp, Cmp, c => Word.cmp.fin(b, b, c),
              Word.cmp(p, t, t), EQ{}, eq.word_cmp_self(p, t)),
            eq.bool_cmp_self(b))

def eq.u32_cmp_self(u: U32) -> {U32.cmp(u, u) == EQ{} : Cmp}:
  match u:
    case U32{+w}:
      eq.word_cmp_self(32n, w)

def eq.order_self(s: String) -> {String.order.go(s, s, EQ{}) == EQ{} : Cmp}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+x}, +t}:
      f = Equal.sym(Cmp, U32.cmp(x, x), EQ{}, eq.u32_cmp_self(x))
      %f : {String.order.go(t, t, _) == EQ{} : Cmp}
      eq.order_self(t)

# every string equals itself
def eq.string_self(s: String) -> {String.eq(s, s) == True{} : Bool}:
  f = Equal.sym(Cmp, String.order.go(s, s, EQ{}), EQ{}, eq.order_self(s))
  %f : {Cmp.is_eq(_) == True{} : Bool}
  {==}
