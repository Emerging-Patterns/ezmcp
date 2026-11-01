# proofs of laws/OldRevisionDropsStructuredContent.bend
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import 0xa81e161008ecc2f297c0a3065cb9b188/src/lazy.bend as Lazy
import ../src/server.bend as Server
import ../laws/OldRevisionDropsStructuredContent.bend as Laws

# --- leaving a member out ---

def without.lem.pair(
  +k: String,
  v: Value.Json,
  r: Value.Json,
  +key: String,
  hit: Bool,
  e: {Value.find.eq(k, key) == hit : Bool},
  ih: {Value.has.go(Server.without.go(r, key), key) == False{} : Bool}
) -> {Value.has.go(Server.without.pair(hit, k, v, Server.without.go(r, key)),
  key) == False{} : Bool}:
  match hit:
    case True{}:
      ih
    case False{}:
      f = Equal.sym(Bool, Value.find.eq(k, key), False{}, e)
      %f : {Lazy.stop(Bool, _, True{},
        _u => Value.has.go(Server.without.go(r, key), key)) == False{} : Bool}
      ih

def without.lem.bind(
  +src: String,
  +num: U32,
  v: Value.Json,
  r: Value.Json,
  +key: String,
  hit: Bool,
  e: {Value.span.eq(src, num, key) == hit : Bool},
  ih: {Value.has.go(Server.without.go(r, key), key) == False{} : Bool}
) -> {Value.has.go(Server.without.bind(hit, src, num, v,
  Server.without.go(r, key)), key) == False{} : Bool}:
  match hit:
    case True{}:
      ih
    case False{}:
      f = Equal.sym(Bool, Value.span.eq(src, num, key), False{}, e)
      %f : {Lazy.stop(Bool, _, True{},
        _u => Value.has.go(Server.without.go(r, key), key)) == False{} : Bool}
      ih

# an object's members less every one named `key` hold none named `key`
def without.lem(
  cells: Value.Json,
  +key: String
) -> {Value.has.go(Server.without.go(cells, key), key) == False{} : Bool}:
  match cells:
    case Value.JPair{+k, v, +r}:
      without.lem.pair(k, v, r, key, Value.find.eq(k, key), {==},
        without.lem(r, key))
    case Value.JBind{+src, +num, v, +r}:
      without.lem.bind(src, num, v, r, key, Value.span.eq(src, num, key), {==},
        without.lem(r, key))
    case Value.JNull{}:
      {==}
    case Value.JBool{_b}:
      {==}
    case Value.JNum{_raw}:
      {==}
    case Value.JStr{_s}:
      {==}
    case Value.JArr{_items}:
      {==}
    case Value.JObj{_pairs}:
      {==}
    case Value.JNil{}:
      {==}
    case Value.JCons{_h, _t}:
      {==}
    case Value.JSpan{_src, _n}:
      {==}

# a value less every member named `key` has none
def without.lem.top(
  v: Value.Json,
  +key: String
) -> {Json.has(Server.without(v, key), key) == False{} : Bool}:
  match v:
    case Value.JObj{pairs}:
      without.lem(pairs, key)
    case Value.JNull{}:
      {==}
    case Value.JBool{_b}:
      {==}
    case Value.JNum{_raw}:
      {==}
    case Value.JStr{_s}:
      {==}
    case Value.JArr{_items}:
      {==}
    case Value.JNil{}:
      {==}
    case Value.JCons{_h, _t}:
      {==}
    case Value.JPair{_k, _v, _r}:
      {==}
    case Value.JSpan{_src, _n}:
      {==}
    case Value.JBind{_src, _n, _v, _r}:
      {==}

def Laws.ran_unstructured(_id, result):
  without.lem.top(result, "structuredContent")

def Laws.ran_old_result(_id, _result):
  {==}

def Laws.without_keeps(k, v, r, key, e):
  f = Equal.sym(Bool, Value.find.eq(k, key), False{}, e)
  %f : {Server.without.pair(_, k, v, Server.without.go(r, key))
    == Value.JPair{k, v, Server.without.go(r, key)} : Value.Json}
  {==}

def Laws.without_drops(k, v, r, key, e):
  f = Equal.sym(Bool, Value.find.eq(k, key), True{}, e)
  %f : {Server.without.pair(_, k, v, Server.without.go(r, key))
    == Server.without.go(r, key) : Value.Json}
  {==}

def Laws.without_keeps_bind(src, num, v, r, key, e):
  f = Equal.sym(Bool, Value.span.eq(src, num, key), False{}, e)
  %f : {Server.without.bind(_, src, num, v, Server.without.go(r, key))
    == Value.JBind{src, num, v, Server.without.go(r, key)} : Value.Json}
  {==}
