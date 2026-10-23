# ezmcp: the proofs. `bend PROOF.bend` is the gate.
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import 0xd3f9c1f02240edb63fd4a109ceb8fa74/src/http.bend as Http
import ./src/rpc.bend as Rpc
import ./src/server.bend as Server
import ./src/web.bend as Web
import ./src/line.bend as Line
import ./src/sse.bend as Sse
import ./src/client.bend as Client
import ./LAWS.bend as Laws

# --- Bool, Char and String facts ---

def bit.emp(b: Bool) -> Type:
  match b:
    case False{}:
      Unit
    case True{}:
      Empty

def bit.clash(e: {False{} == True{} : Bool}) -> Empty:
  %e : bit.emp(_)
  Unit{}

def bit.gone(a, -A: Kind(a), e: Empty) -> A:
  match e:

# anything follows from False == True
def absurd(a, -A: Kind(a), e: {False{} == True{} : Bool}) -> A:
  bit.gone(a, A, bit.clash(e))

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

# True or anything is True, anything or True is True
def eq.or_true(a: Bool) -> {Bool.or(a, True{}) == True{} : Bool}:
  match a:
    case False{}:
      {==}
    case True{}:
      {==}

# an array's items are the list it was built from
def eq.items_arr(
  xs: List<&2, Value.Json>
) -> {Value.items.go(Value.arr.go(xs)) == xs : List<&2, Value.Json>}:
  match xs:
    case []:
      {==}
    case h <> t:
      Equal.cong(List<&2, Value.Json>, List<&2, Value.Json>, r => h <> r,
        Value.items.go(Value.arr.go(t)), t, eq.items_arr(t))

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
      absurd(&2, {v == True{} : Bool}, e)

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
      absurd(&2, {Laws.pieces.ok([[b]]) == True{} : Bool}, h)
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
      absurd(&2, {Bool.and(Laws.line.ok([b]), Laws.pieces.ok.at(more, q))
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
      absurd(&2, {Laws.pieces.ok(Line.split.put(b, [])) == True{} : Bool}, h)
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

# an origin check whose second test held holds, whatever the first
def eq.origin_or_true(
  hit: Bool
) -> {Web.origin.or(hit, _u => Web.origin.or(True{}, _v => False{}))
  == True{} : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      {==}

# a hit whose misses are false is the hit
def eq.origin_or_or(
  hit: Bool
) -> {Web.origin.or(Web.origin.or(hit, _u => False{}), _v => False{})
  == hit : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      {==}

# --- version negotiation ---

# the answer for a revision whose support is b is a supported one
def negotiate.lem(
  v: String,
  b: Bool,
  e: {Server.supported(v) == b : Bool}
) -> {Server.supported(Server.negotiate.of(v, b)) == True{} : Bool}:
  match b:
    case True{}:
      e
    case False{}:
      {==}

# --- initialize results, whatever the instructions ---

# an initialize result's members, with the instructions' emptiness as b
def init.of(
  version: String,
  caps: Value.Json,
  info: Value.Json,
  instructions: String,
  b: Bool
) -> Value.Json:
  Json.obj(List.append(&1, String & Value.Json,
    [("protocolVersion", Json.str(version)), ("capabilities", caps),
      ("serverInfo", info)], Server.init.extra(instructions, b)))

def init.lem.info(
  version: String,
  caps: Value.Json,
  info: Value.Json,
  instructions: String,
  b: Bool
) -> {Json.get(init.of(version, caps, info, instructions, b), "serverInfo") == info : Value.Json}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def init.lem.caps(
  version: String,
  caps: Value.Json,
  info: Value.Json,
  instructions: String,
  b: Bool
) -> {Json.get(init.of(version, caps, info, instructions, b), "capabilities") == caps : Value.Json}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def init.lem.version(
  version: String,
  caps: Value.Json,
  info: Value.Json,
  instructions: String,
  b: Bool
) -> {Json.get(init.of(version, caps, info, instructions, b), "protocolVersion") == Json.str(version) : Value.Json}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def Laws.request_is_ask(_id, _m, _params, _r, _e):
  {==}

def Laws.id_string(_s):
  {==}

def Laws.id_number(_raw):
  {==}

def Laws.int_minus(_t):
  {==}

def Laws.int_digits(h, t, e):
  f = Equal.sym(Bool, Char.is_eq(h, '-'), False{}, e)
  %f : {Rpc.int.text.of(h, t, _) == Rpc.digits(SCon{h, t}) : Bool}
  {==}

def Laws.id_other(v, es, en):
  fs = Equal.sym(Maybe<&2, String>, Json.as_str(v), None{}, es)
  fn = Equal.sym(Maybe<&2, String>, Json.as_num(v), None{}, en)
  %fs : {Rpc.id.str(_, v) == False{} : Bool}
  %fn : {Rpc.id.num(_) == False{} : Bool}
  {==}

def Laws.request_bad_id(_id, _m, _params, _r, _e):
  {==}

def Laws.notification_is_tell(_ok, _id, _m, _params, _r, _e):
  {==}

def Laws.tell_is_quiet(_srv, _m, _params):
  {==}

def Laws.response_is_answer(id, _params, r, e, one):
  f = Equal.sym(Bool, Rpc.one(r, e), True{}, one)
  %f : {Bool.pick(Rpc.Msg, _, Rpc.Answer{id},
    Rpc.Junk{id, "Invalid Request: no method"}) == Rpc.Answer{id} : Rpc.Msg}
  {==}

def Laws.answer_is_quiet(_srv, _id):
  {==}

def Laws.reply_id(_id, out):
  match out:
    case Rpc.Ok{r}:
      {==}
    case Rpc.Err{c, message}:
      {==}

def Laws.answer_id(id, s):
  match s:
    case Server.Now{out}:
      Laws.reply_id(id, out)
    case Server.Call{name, args}:
      {==}

def Laws.ran_id(_id, _result):
  {==}

def Laws.reply_ok_one(_id, _result):
  {==}

def Laws.reply_err_one(_id, _c, _message):
  {==}

def Laws.code_integer(c):
  match c:
    case Rpc.ParseError{}:
      {==}
    case Rpc.InvalidRequest{}:
      {==}
    case Rpc.MethodNotFound{}:
      {==}
    case Rpc.InvalidParams{}:
      {==}
    case Rpc.InternalError{}:
      {==}

def Laws.reply_err_fields(_id, _c, _message):
  {==}

def Laws.reply_v2(_id, out):
  match out:
    case Rpc.Ok{r}:
      {==}
    case Rpc.Err{c, message}:
      {==}

def Laws.request_v2(_id, _m, _params):
  {==}

def Laws.notice_v2(_m, _params):
  {==}

def Laws.not_v2_junk(_has_id, _ok, _id, _m, _params, _r, _e):
  {==}

def Laws.parse_error(srv, text, e):
  f = Equal.sym(Maybe<&2, Value.Json>, Json.parse(text), None{}, e)
  %f : {Server.parsed(srv, _)
    == Server.Fault{Rpc.reply(Json.null(),
      Rpc.Err{Rpc.ParseError{}, "Parse error"})} : Server.Act}
  {==}

def Laws.not_object_junk(_v2, _has_id, _ok, _id, _m, _params, _r, _e):
  {==}

def Laws.batch_junk(_items):
  {==}

def Laws.no_method_junk(has_id, ok, id, _params, r, e, none):
  f = Equal.sym(Bool, Bool.and(Bool.and(has_id, ok), Rpc.one(r, e)), False{},
    none)
  %f : {Bool.pick(Rpc.Msg, _, Rpc.Answer{id},
    Rpc.Junk{Rpc.head.id(has_id, ok, id), "Invalid Request: no method"})
    == Rpc.Junk{Rpc.head.id(has_id, ok, id), "Invalid Request: no method"}
    : Rpc.Msg}
  {==}

def Laws.junk_fault(_srv, _id, _why):
  {==}

def Laws.junk_id(_has_id, _ok, _id):
  {==}

def Laws.method_not_found(srv, m, params, e):
  f = Equal.sym(Server.Method, Server.method.of(m), Server.Other{}, e)
  %f : {Server.dispatch.of(srv, m, params, _)
    == Server.Now{Rpc.Err{Rpc.MethodNotFound{}, "Method not found: " ++ m}}
    : Server.Step}
  {==}

def Laws.ask_dispatch(_srv, _id, _m, _params):
  {==}

def Laws.initialize_dispatch(_srv, _params):
  {==}

def Laws.init_info(name, version, instructions, tools, params):
  init.lem.info(Server.negotiate(Json.as_str(Json.get(params,
    "protocolVersion"))), Server.capabilities(tools),
    Server.init.info(name, version), instructions,
    String.is_empty(instructions))

def Laws.init_instructions(name, version, instructions, tools, params, e):
  f = Equal.sym(Bool, String.is_empty(instructions), False{}, e)
  %f : {Json.get(init.of(Server.negotiate(Json.as_str(Json.get(params,
    "protocolVersion"))), Server.capabilities(tools),
    Server.init.info(name, version), instructions, _), "instructions")
    == Json.str(instructions) : Value.Json}
  {==}

def Laws.init_no_instructions(name, version, instructions, tools, params, e):
  f = Equal.sym(Bool, String.is_empty(instructions), True{}, e)
  %f : {Json.has(init.of(Server.negotiate(Json.as_str(Json.get(params,
    "protocolVersion"))), Server.capabilities(tools),
    Server.init.info(name, version), instructions, _), "instructions")
    == False{} : Bool}
  {==}

def Laws.init_version(srv, params):
  match srv:
    case Server.Server{name, version, +instructions, tools}:
      init.lem.version(Server.negotiate(Json.as_str(Json.get(params,
        "protocolVersion"))), Server.capabilities(tools),
        Server.init.info(name, version), instructions,
        String.is_empty(instructions))

def Laws.negotiate_echo(v, e):
  f = Equal.sym(Bool, Server.supported(v), True{}, e)
  %f : {Server.negotiate.of(v, _) == v : String}
  {==}

def Laws.negotiate_latest(v, e):
  f = Equal.sym(Bool, Server.supported(v), False{}, e)
  %f : {Server.negotiate.of(v, _) == Server.latest() : String}
  {==}

def Laws.negotiate_supported(asked):
  match asked:
    case None{}:
      {==}
    case Some{+v}:
      negotiate.lem(v, Server.supported(v), {==})

def Laws.init_caps(name, version, instructions, tools, params):
  init.lem.caps(Server.negotiate(Json.as_str(Json.get(params,
    "protocolVersion"))), Server.capabilities(tools),
    Server.init.info(name, version), instructions,
    String.is_empty(instructions))

def Laws.caps_tools(_t, _rest):
  {==}

def Laws.caps_none(tools, e):
  match tools:
    case []:
      {==}
    case t <> rest:
      absurd(&2, {Server.capabilities(t <> rest) == Json.obj([]) : Value.Json},
        e)

def Laws.ping_empty(_srv, _params):
  {==}

def Laws.list_dispatch(_srv, _params):
  {==}

def Laws.list_items(_name, _version, _instructions, tools):
  eq.items_arr(Server.tool.all(tools))

def Laws.list_each(_t, _rest):
  {==}

def Laws.tool_fields(_name, _description, _input):
  {==}

def Laws.list_one_page(srv):
  match srv:
    case Server.Server{name, version, instructions, tools}:
      {==}

def Laws.call_dispatch(_srv, _params):
  {==}

def Laws.known_named(name, _description, _input, rest):
  f = Equal.sym(Bool, String.eq(name, name), True{}, eq.string_self(name))
  %f : {Server.known.or(_, _u => Server.known(rest, name)) == True{} : Bool}
  {==}

def Laws.call_runs(name, params, has, obj):
  fh = Equal.sym(Bool, Json.has(params, "arguments"), True{}, has)
  fo = Equal.sym(Bool, Json.is_obj(Json.get(params, "arguments")), True{}, obj)
  %fh : {Server.call.args(name, _, Json.get(params, "arguments"))
    == Server.Call{name, Json.get(params, "arguments")} : Server.Step}
  %fo : {Bool.pick(Server.Step, _, Server.Call{name, Json.get(params,
    "arguments")}, Server.invalid("tools/call: arguments must be an object"))
    == Server.Call{name, Json.get(params, "arguments")} : Server.Step}
  {==}

def Laws.call_no_args(name, params, has):
  fh = Equal.sym(Bool, Json.has(params, "arguments"), False{}, has)
  %fh : {Server.call.args(name, _, Json.get(params, "arguments"))
    == Server.Call{name, Json.obj([])} : Server.Step}
  {==}

def Laws.call_named(_name, _description, _version, _instructions, tools, params, n, e):
  f = Equal.sym(Maybe<&2, String>, Json.as_str(Json.get(params, "name")),
    Some{n}, e)
  %f : {Server.call.named(tools, params, _)
    == Server.call.known(n, params, Server.known(tools, n)) : Server.Step}
  {==}

def Laws.call_is_run(_id, _name, _args):
  {==}

def Laws.call_unknown(_name, _params):
  {==}

def Laws.known_none(_name):
  {==}

def Laws.call_no_name(srv, params, e):
  match srv:
    case Server.Server{name, version, instructions, tools}:
      f = Equal.sym(Maybe<&2, String>, Json.as_str(Json.get(params, "name")),
        None{}, e)
      %f : {Server.call.named(tools, params, _)
        == Server.Now{Rpc.Err{Rpc.InvalidParams{},
          "tools/call: params.name must be a string"}} : Server.Step}
      {==}

def Laws.call_bad_args(name, params, has, obj):
  fh = Equal.sym(Bool, Json.has(params, "arguments"), True{}, has)
  fo = Equal.sym(Bool, Json.is_obj(Json.get(params, "arguments")), False{}, obj)
  %fh : {Server.call.args(name, _, Json.get(params, "arguments"))
    == Server.Now{Rpc.Err{Rpc.InvalidParams{},
      "tools/call: arguments must be an object"}} : Server.Step}
  %fo : {Bool.pick(Server.Step, _, Server.Call{name, Json.get(params,
    "arguments")}, Server.invalid("tools/call: arguments must be an object"))
    == Server.Now{Rpc.Err{Rpc.InvalidParams{},
      "tools/call: arguments must be an object"}} : Server.Step}
  {==}

def Laws.result_flag(_blocks, _bad):
  {==}

def Laws.result_content(blocks, _bad):
  eq.items_arr(blocks)

def Laws.text_block(_s):
  {==}

def Laws.ran_result(_id, _result):
  {==}

def Laws.structured_value(_v, _bad):
  {==}

def Laws.structured_text(v, _bad):
  eq.items_arr([Server.text(Json.print(v))])

def Laws.web_parts(_srv, _path, _origins, _m, _target, _headers, _body):
  {==}

def Laws.web_post(_srv, _body):
  {==}

def Laws.web_send(_reply):
  {==}

def Laws.web_ran(_id, _result):
  {==}

def Laws.web_run(_id, _name, _args):
  {==}

def Laws.web_tell(_srv, _m, _params):
  {==}

def Laws.web_answer(_srv, _id):
  {==}

def Laws.web_fault(_reply):
  {==}

def Laws.web_bad(_srv, _path, _origins, _why):
  {==}

def Laws.web_not_post(_srv, _version, _body):
  {==}

def Laws.web_origin(_srv, _is_post, _version, _body):
  {==}

def Laws.web_version(_srv, _body):
  {==}

def Laws.version_ok(_v):
  {==}

def Laws.web_path(_srv, _allowed, _is_post, _version, _body):
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

def Laws.line_blank(srv, text, e):
  f = Equal.sym(Bool, String.is_empty(String.trim(text)), True{}, e)
  %f : {Line.line.of(srv, text, _) == Server.Quiet{} : Server.Act}
  {==}

def Laws.line_message(srv, text, e):
  f = Equal.sym(Bool, String.is_empty(String.trim(text)), False{}, e)
  %f : {Line.line.of(srv, text, _) == Server.step(srv, text) : Server.Act}
  {==}

def Laws.frame_line(_v):
  {==}

def Laws.request_id(_id, _m, _params):
  {==}

def Laws.notice_no_id(_m, _params):
  {==}

def Laws.call_request(_id, _name, _args):
  {==}

def Laws.initialize_params(_id, _name, _version):
  {==}

def Laws.headers_first(v, e):
  f = Equal.sym(Bool, String.is_empty(v), True{}, e)
  %f : {Bool.pick(List<&2, Http.Header>, _, [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"}], [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"},
      Http.H{"MCP-Protocol-Version", v}])
    == [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"}] : List<&2, Http.Header>}
  {==}

def Laws.headers_version(v, e):
  f = Equal.sym(Bool, String.is_empty(v), False{}, e)
  %f : {Bool.pick(List<&2, Http.Header>, _, [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"}], [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"},
      Http.H{"MCP-Protocol-Version", v}])
    == [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"},
      Http.H{"MCP-Protocol-Version", v}] : List<&2, Http.Header>}
  {==}

def Laws.took_ok(_ctype, _text, _status):
  {==}

def Laws.body_sse(_text):
  {==}

def Laws.body_json(_text):
  {==}

def Laws.sse_data(_cur, _last, _x):
  {==}

def Laws.sse_end(_d, _last):
  {==}

def Laws.sse_more(_d, _x):
  {==}

def Laws.read_got(_id, _result, _c, _m):
  {==}

def Laws.read_refused(_id, _result, _c, _m):
  {==}

def Laws.read_both(_id, _result, b, _c, _m):
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def Laws.read_not_v2(_id, _r, _result, _e, _c, _m):
  {==}

def Laws.read_not_json(text, e):
  f = Equal.sym(Maybe<&2, Value.Json>, Json.parse(text), None{}, e)
  %f : {Rpc.read.parsed(_) == Rpc.Unread{"the reply is not JSON"} : Rpc.Reply}
  {==}

def Laws.took_status(_ctype, _text, _status):
  {==}

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

def Laws.origin_absent(_origins):
  {==}

def Laws.origin_loopback(origins, origin, e):
  f = Equal.sym(Bool, Web.loopback(origin), True{}, e)
  %f : {Web.origin.or(String.is_empty(origin), _u => Web.origin.or(_,
    _v => Web.origin.listed(origins, origin))) == True{} : Bool}
  eq.origin_or_true(String.is_empty(origin))

def Laws.loopback_localhost(port):
  eq.origin_or_or(Rpc.digits(port))

def Laws.loopback_ipv4(port):
  eq.origin_or_or(Rpc.digits(port))

def Laws.origin_other(origins, origin, ee, el):
  fe = Equal.sym(Bool, String.is_empty(origin), False{}, ee)
  fl = Equal.sym(Bool, Web.loopback(origin), False{}, el)
  %fe : {Web.origin.or(_, _u => Web.origin.or(Web.loopback(origin),
    _v => Web.origin.listed(origins, origin)))
    == Web.origin.listed(origins, origin) : Bool}
  %fl : {Web.origin.or(_, _v => Web.origin.listed(origins, origin))
    == Web.origin.listed(origins, origin) : Bool}
  {==}

def Laws.origin_listed(origin, rest):
  f = Equal.sym(Bool, String.eq(origin, origin), True{}, eq.string_self(origin))
  %f : {Web.origin.or(_, _u => Web.origin.listed(rest, origin)) == True{}
    : Bool}
  {==}

def Laws.origin_none(_origin):
  {==}

def Laws.origin_unlisted(listed, rest, origin, e):
  f = Equal.sym(Bool, String.eq(listed, origin), False{}, e)
  %f : {Web.origin.or(_, _u => Web.origin.listed(rest, origin))
    == Web.origin.listed(rest, origin) : Bool}
  {==}
