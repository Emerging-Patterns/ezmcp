# ezmcp/src/openapi: an OpenAPI 3.0 or 3.1 document as an MCP tool table,
# and a tool call as the HTTP request it stands for, with no IO. Every
# operation of the document's paths is one tool: its name is the
# operation's id, its arguments are the operation's parameters by name and
# its request body as `requestBody`. A call's arguments are checked against
# the tool's input schema, then filled into the path template, the query
# string and the header fields. The caller reads the document and sends the
# request. Where the specifications leave a choice open, the choice is
# openapi-mcp-generator's (v4), so a server it generated keeps its tools.
# SPEC.md MCP-OAS lists what is guaranteed.
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import 0xedb2120a04a47dc18c3a756ec7c62750/src/http.bend as Http
import 0xedb2120a04a47dc18c3a756ec7c62750/src/pct.bend as Pct
import 0xedb2120a04a47dc18c3a756ec7c62750/src/qs.bend as Qs
import ./server.bend as Server

# where a parameter goes (Parameter Object `in`); InNone for a location
# OpenAPI does not have
type Place is Data:
  InPath{}
  InQuery{}
  InHeader{}
  InCookie{}
  InNone{}

# a parameter a request is built from: its name and where it goes
type Param is Data:
  Param{name: String, place: Place}

# one operation as a tool: the tool's name, description and input schema,
# and what its calls are sent as: the method (upper case), the path
# template, the parameters, and the request body's media type ("" for none)
type Op is Data:
  Op{name: String, description: String, input: Value.Json, method: String,
    path: String, params: List<&2, Param>, media: String}

# the request a tool call stands for: a method, a target (the path and its
# query), the header fields and the body; or the path template when a
# template expression is still in it
type Call is Data:
  Send{method: String, target: String, headers: List<&2, Http.Header>,
    body: Maybe<&2, String>}
  Unfilled{path: String}

# --- searches ---

# true at a hit, else the rest of the search
def or.else(hit: Bool, rest: Unit -> Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      rest(Unit{})

# false at a miss, else the rest of the check
def and.then(ok: Bool, rest: Unit -> Bool) -> Bool:
  match ok:
    case True{}:
      rest(Unit{})
    case False{}:
      False{}

# --- object members ---

# an object member: its name and value, reusable
def Mem() -> Data:
  Sigma<&2, &2, String, _ => Value.Json>

# members as the cells of an object, in order
def cells(ps: List<&2, Mem()>) -> Value.Json:
  match ps:
    case []:
      Value.JNil{}
    case (key, val) <> rest:
      Value.JPair{key, val, cells(rest)}

# the object of members, in order
def object(ps: List<&2, Mem()>) -> Value.Json:
  Value.JObj{cells(ps)}

def members.go(cs: Value.Json) -> List<&2, Mem()>:
  match cs:
    case Value.JPair{key, val, rest}:
      (key, val) <> members.go(rest)
    case Value.JBind{src, +n, val, rest}:
      (Value.span.str(src, n, U32.is_zero(n)), val) <> members.go(rest)
    case other:
      []

# an object's members in order; none for any other value
def members(val: Value.Json) -> List<&2, Mem()>:
  match val:
    case Value.JObj{pairs}:
      members.go(pairs)
    case other:
      []

def put.at(
  hit: Bool,
  k2: String,
  v2: Value.Json,
  rest: List<&2, Mem()>,
  key: String,
  val: Value.Json,
  more: Unit -> List<&2, Mem()>
) -> List<&2, Mem()>:
  match hit:
    case True{}:
      (key, val) <> rest
    case False{}:
      (k2, v2) <> more(Unit{})

# members with `key` set to `val`: in the place of the first member of that
# name, else last, as a JavaScript assignment puts it
def put(ps: List<&2, Mem()>, +key: String, +val: Value.Json) -> List<&2, Mem()>:
  match ps:
    case []:
      [(key, val)]
    case (+k2, v2) <> +rest:
      put.at(String.eq(k2, key), k2, v2, rest, key, val, _u => put(rest, key, val))

def drop.at(
  hit: Bool,
  k2: String,
  v2: Value.Json,
  rest: List<&2, Mem()>
) -> List<&2, Mem()>:
  match hit:
    case True{}:
      rest
    case False{}:
      (k2, v2) <> rest

# members less every one named `key`, the rest in order
def drop(ps: List<&2, Mem()>, +key: String) -> List<&2, Mem()>:
  match ps:
    case []:
      []
    case (+k2, v2) <> rest:
      drop.at(String.eq(k2, key), k2, v2, drop(rest, key))

# whether members have one named `key`
def named(ps: List<&2, Mem()>, +key: String) -> Bool:
  match ps:
    case []:
      False{}
    case (+k2, _v) <> rest:
      or.else(String.eq(k2, key), _u => named(rest, key))

def lookup.at(
  hit: Bool,
  val: Value.Json,
  more: Unit -> Maybe<&2, Value.Json>
) -> Maybe<&2, Value.Json>:
  match hit:
    case True{}:
      Some{val}
    case False{}:
      more(Unit{})

# the value of the first member named `key`
def lookup(ps: List<&2, Mem()>, +key: String) -> Maybe<&2, Value.Json>:
  match ps:
    case []:
      None{}
    case (k2, val) <> rest:
      lookup.at(String.eq(k2, key), val, _u => lookup(rest, key))

# a member's value, null when there is none
def value(ps: List<&2, Mem()>, key: String) -> Value.Json:
  Maybe.default(&2, Value.Json, lookup(ps, key), Json.null())

# --- JSON values as JavaScript reads them ---

# a string when it is not empty, as JavaScript's `||` takes it
def full(text: Maybe<&2, String>) -> Maybe<&2, String>:
  match text:
    case None{}:
      None{}
    case Some{+str}:
      Bool.pick(Maybe<&2, String>, String.is_empty(str), None{}, Some{str})

# the first of two maybe strings that is there
def first(lead: Maybe<&2, String>, next: Maybe<&2, String>) -> Maybe<&2, String>:
  match lead:
    case Some{str}:
      Some{str}
    case None{}:
      next

# whether a value is JSON true
def is_true(val: Value.Json) -> Bool:
  match val:
    case Value.JBool{flag}:
      flag
    case other:
      False{}

# whether a value is JSON null
def is_null(val: Value.Json) -> Bool:
  match val:
    case Value.JNull{}:
      True{}
    case other:
      False{}

def is_str.of(text: Maybe<&2, String>, +str: String) -> Bool:
  match text:
    case None{}:
      False{}
    case Some{got}:
      String.eq(got, str)

# whether a value is the string `str`
def is_str(val: Value.Json, +str: String) -> Bool:
  is_str.of(Json.as_str(val), str)

# a member's string, "" when it is not one
def str.at(val: Value.Json, key: String) -> String:
  Maybe.default(&2, String, Json.as_str(Json.get(val, key)), "")

# --- references (Reference Object, RFC 6901) ---

def token.go(cs: String) -> String:
  match cs:
    case SNil{}:
      SNil{}
    case SCon{'~', SCon{'1', rest}}:
      SCon{'/', token.go(rest)}
    case SCon{'~', SCon{'0', rest}}:
      SCon{'~', token.go(rest)}
    case SCon{ch, rest}:
      SCon{ch, token.go(rest)}

# one reference token decoded: `~1` as `/` and `~0` as `~` (RFC 6901 §4)
def token(text: String) -> String:
  token.go(text)

def walk.at(
  hit: Bool,
  next: Value.Json,
  more: Value.Json -> Maybe<&2, Value.Json>
) -> Maybe<&2, Value.Json>:
  match hit:
    case True{}:
      more(next)
    case False{}:
      None{}

# the value at a pointer's tokens, each a member name, or none when a member
# is missing
def walk(toks: List<&2, String>, +val: Value.Json) -> Maybe<&2, Value.Json>:
  match toks:
    case []:
      Some{val}
    case tok <> rest:
      +key = token(tok)
      walk.at(Json.has(val, key), Json.get(val, key), got => walk(rest, got))

def resolve.at(local: Bool, +doc: Value.Json, ref: String) -> Maybe<&2, Value.Json>:
  match local:
    case True{}:
      walk(String.split(String.drop(ref, 2n), '/'), doc)
    case False{}:
      None{}

# what a local reference (`#/` and a JSON Pointer) points to in the
# document; none for a reference that is not local or points to nothing
def resolve(+doc: Value.Json, +ref: String) -> Maybe<&2, Value.Json>:
  resolve.at(String.starts_with(ref, "#/"), doc, ref)

# a `$ref` member's string, when the cells have one
def ref.of(pairs: Value.Json) -> Maybe<&2, String>:
  Json.as_str(Value.find(pairs, "$ref"))

# whether a reference is one being followed already
def seen(refs: List<&2, String>, +ref: String) -> Bool:
  match refs:
    case []:
      False{}
    case +got <> rest:
      or.else(String.eq(got, ref), _u => seen(rest, ref))

def merge.one(
  hit: Bool,
  +sib: List<&2, Mem()>,
  key: String,
  val: Value.Json
) -> List<&2, Mem()>:
  match hit:
    case True{}:
      sib
    case False{}:
      List.append(&2, Mem(), sib, [(key, val)])

def merge.add(ts: List<&2, Mem()>, +sib: List<&2, Mem()>) -> List<&2, Mem()>:
  match ts:
    case []:
      sib
    case (+key, val) <> rest:
      merge.add(rest, merge.one(named(sib, key), sib, key, val))

def merge.of(empty: Bool, sib: List<&2, Mem()>, +target: Value.Json) -> Value.Json:
  match empty:
    case True{}:
      target
    case False{}:
      object(merge.add(members(target), sib))

# a reference's target with the reference object's other members: the
# target itself when there are none; else those members first, then the
# target's members they do not name (Reference Object: a sibling
# `description` overrides the target's)
def merge(+sib: List<&2, Mem()>, +target: Value.Json) -> Value.Json:
  merge.of(List.is_empty(&2, Mem(), sib), sib, target)

# the schema a reference cycle stands for
def cyclic() -> Value.Json:
  Json.obj([("type", Json.str("object"))])

def deref.found(
  found: Maybe<&2, Value.Json>,
  plain: Unit -> Value.Json,
  follow: Value.Json -> Value.Json
) -> Value.Json:
  match found:
    case None{}:
      plain(Unit{})
    case Some{target}:
      merge(drop(members(plain(Unit{})), "$ref"), follow(target))

def deref.ref(
  cycle: Bool,
  +ref: String,
  +doc: Value.Json,
  plain: Unit -> Value.Json,
  follow: String -> Value.Json -> Value.Json
) -> Value.Json:
  match cycle:
    case True{}:
      cyclic()
    case False{}:
      deref.found(resolve(doc, ref), plain, follow(ref))

def deref.obj(
  ref: Maybe<&2, String>,
  +doc: Value.Json,
  +refs: List<&2, String>,
  plain: Unit -> Value.Json,
  follow: String -> Value.Json -> Value.Json
) -> Value.Json:
  match ref:
    case None{}:
      plain(Unit{})
    case Some{+got}:
      deref.ref(seen(refs, got), got, doc, plain, follow)

# a value with every local reference in it replaced by its target, merged
# with the reference object's other members (`merge`); a reference to one
# of `refs`, the references being followed, is a cycle (`cyclic`), and one
# that does not resolve is left as it is. `fuel` bounds how deep values and
# references nest
def deref(
  fuel: Nat,
  val: Value.Json,
  +doc: Value.Json,
  +refs: List<&2, String>
) -> Value.Json:
  match fuel:
    case 0n:
      val
    case 1n+(+less):
      match val:
        case Value.JObj{+pairs}:
          deref.obj(ref.of(pairs), doc, refs,
            _u => Value.JObj{deref(1n+less, pairs, doc, refs)},
            ref => target => deref(less, target, doc, ref <> refs))
        case Value.JArr{items}:
          Value.JArr{deref(1n+less, items, doc, refs)}
        case Value.JCons{head, tail}:
          Value.JCons{deref(1n+less, head, doc, refs),
            deref(1n+less, tail, doc, refs)}
        case Value.JPair{key, item, rest}:
          Value.JPair{key, deref(1n+less, item, doc, refs),
            deref(1n+less, rest, doc, refs)}
        case Value.JBind{src, n, item, rest}:
          Value.JBind{src, n, deref(1n+less, item, doc, refs),
            deref(1n+less, rest, doc, refs)}
        case other:
          other

# how deep a value's references and schemas may nest before the rest is
# left as it is
def depth() -> Nat:
  64n

# a value of the document with its local references followed
def dereferenced(+doc: Value.Json, val: Value.Json) -> Value.Json:
  deref(depth(), val, doc, [])

# --- schemas (Schema Object) ---

# the OpenAPI 3.0 fields of a Schema Object that are not JSON Schema, which
# an input schema leaves out
def extras() -> List<&2, String>:
  ["nullable", "example", "xml", "externalDocs", "deprecated", "readOnly",
    "writeOnly"]

# members less every one named by `keys`
def drop.all(keys: List<&2, String>, ps: List<&2, Mem()>) -> List<&2, Mem()>:
  match keys:
    case []:
      ps
    case key <> rest:
      drop.all(rest, drop(ps, key))

# `integer` as JSON Schema's `number`, any other type as it is
def number(+typ: Value.Json) -> Value.Json:
  Bool.pick(Value.Json, is_str(typ, "integer"), Json.str("number"), typ)

def with.null.arr(has: Bool, +items: List<&2, Value.Json>) -> Value.Json:
  match has:
    case True{}:
      Json.arr(items)
    case False{}:
      Json.arr(List.append(&2, Value.Json, items, [Json.str("null")]))

def any.null(items: List<&2, Value.Json>) -> Bool:
  match items:
    case []:
      False{}
    case item <> rest:
      or.else(is_str(item, "null"), _u => any.null(rest))

# a type that also admits null (OpenAPI 3.0 `nullable`): a type name as an
# array of it and "null", an array of names with "null" added when it lacks
# it, anything else as it is
def with.null(typ: Value.Json) -> Value.Json:
  match typ:
    case Value.JStr{str}:
      Json.arr([Value.JStr{str}, Json.str("null")])
    case Value.JSpan{src, +n}:
      Json.arr([Value.JSpan{src, n}, Json.str("null")])
    case Value.JArr{+cs}:
      with.null.arr(any.null(Json.items(Value.JArr{cs})),
        Json.items(Value.JArr{cs}))
    case other:
      other

def typed.null(nullable: Bool, +typ: Value.Json) -> Value.Json:
  match nullable:
    case True{}:
      with.null(number(typ))
    case False{}:
      number(typ)

def typed.of(
  ps: List<&2, Mem()>,
  typ: Maybe<&2, Value.Json>,
  nullable: Bool
) -> List<&2, Mem()>:
  match typ:
    case None{}:
      ps
    case Some{+got}:
      put(ps, "type", typed.null(nullable, got))

# a schema's own members as an input schema has them: the OpenAPI 3.0
# extras left out, `integer` as `number`, and `nullable` true adding null to
# an explicit type, every other member as it is, in order
def own(+ps: List<&2, Mem()>) -> List<&2, Mem()>:
  typed.of(drop.all(extras(), ps), lookup(ps, "type"),
    is_true(value(ps, "nullable")))

# what a mapped schema recurses into: its properties when its type is
# "object", its items when its type is "array", else nothing
type Kids is Data:
  NoKids{}
  PropKids{cells: Value.Json}
  ItemKid{item: Value.Json}

def kids.props(props: Value.Json) -> Kids:
  match props:
    case Value.JObj{cs}:
      PropKids{cs}
    case other:
      NoKids{}

def kids.item(+item: Value.Json) -> Kids:
  Bool.pick(Kids, Json.is_obj(item), ItemKid{item}, NoKids{})

def kids.array(array: Bool, +ps: List<&2, Mem()>) -> Kids:
  match array:
    case True{}:
      kids.item(value(ps, "items"))
    case False{}:
      NoKids{}

def kids.of(object: Bool, array: Bool, +ps: List<&2, Mem()>) -> Kids:
  match object:
    case True{}:
      kids.props(value(ps, "properties"))
    case False{}:
      kids.array(array, ps)

# what a schema's members recurse into: its properties' cells when its
# type is "object" and its properties an object, its items when its type is
# "array" and its items an object, else nothing
def kids(+ps: List<&2, Mem()>) -> Kids:
  +typ = value(ps, "type")
  kids.of(is_str(typ, "object"), is_str(typ, "array"), ps)

def kids.put(
  +ps: List<&2, Mem()>,
  kid: Kids,
  props: Value.Json -> Value.Json,
  item: Value.Json -> Value.Json
) -> Value.Json:
  match kid:
    case NoKids{}:
      object(ps)
    case PropKids{cs}:
      object(put(ps, "properties", Value.JObj{props(cs)}))
    case ItemKid{got}:
      object(put(ps, "items", item(got)))

# whether a property's value is a schema to map, kept as it is, or left out
type Prop is Data:
  PMap{}
  PKeep{}
  PDrop{}

def prop.of(val: Value.Json) -> Prop:
  match val:
    case Value.JObj{_c}:
      PMap{}
    case Value.JBool{_b}:
      PKeep{}
    case other:
      PDrop{}

def prop.put(
  kind: Prop,
  key: String,
  +val: Value.Json,
  go: Value.Json -> Value.Json,
  rest: Value.Json
) -> Value.Json:
  match kind:
    case PMap{}:
      Value.JPair{key, go(val), rest}
    case PKeep{}:
      Value.JPair{key, val, rest}
    case PDrop{}:
      rest

# what `shape` reads its value as: a schema, or the cells of a properties
# object
type Read is Data:
  ASchema{}
  AProps{}

# a schema as an input schema (`own`), its properties' and items' schemas
# mapped the same way; or the cells of a properties object with every
# schema value mapped, a boolean kept and any other value left out. `fuel`
# bounds how deep schemas nest
def shape(fuel: Nat, val: Value.Json, read: Read) -> Value.Json:
  match fuel:
    case 0n:
      val
    case 1n+(+less):
      match val read:
        case Value.JObj{pairs} ASchema{}:
          +ps = own(members(Value.JObj{pairs}))
          kids.put(ps, kids(ps), cs => shape(less, cs, AProps{}),
            got => shape(less, got, ASchema{}))
        case Value.JPair{key, +item, rest} AProps{}:
          prop.put(prop.of(item), key, item, got => shape(less, got, ASchema{}),
            shape(1n+less, rest, AProps{}))
        case Value.JBind{src, +n, +item, rest} AProps{}:
          prop.put(prop.of(item), Value.span.str(src, n, U32.is_zero(n)), item,
            got => shape(less, got, ASchema{}), shape(1n+less, rest, AProps{}))
        case other ASchema{}:
          other
        case other AProps{}:
          Value.JNil{}

# a Schema Object as the JSON Schema of an input
def schema(val: Value.Json) -> Value.Json:
  shape(depth(), val, ASchema{})

# --- names (Operation Object operationId) ---

# whether a character may stand in a tool name: an ASCII letter or digit,
# `_` or `-`
def name.ok(+cp: U32) -> Bool:
  Bool.or(Bool.and(U32.is_le(65, cp), U32.is_le(cp, 90)),
    Bool.or(Bool.and(U32.is_le(97, cp), U32.is_le(cp, 122)),
      Bool.or(Bool.and(U32.is_le(48, cp), U32.is_le(cp, 57)),
        Bool.or(U32.is_eq(cp, 95), U32.is_eq(cp, 45)))))

def name.char(ok: Bool, +cp: U32) -> Char:
  match ok:
    case True{}:
      Chr{cp}
    case False{}:
      '_'

# a string as a tool name: each character that may not stand in one
# (`name.ok`) as `_`, one for one
def sanitize(text: String) -> String:
  match text:
    case SNil{}:
      SNil{}
    case SCon{Chr{+cp}, rest}:
      SCon{name.char(name.ok(cp), cp), sanitize(rest)}

def title.go(cs: String) -> String:
  match cs:
    case SNil{}:
      SNil{}
    case SCon{'-', SCon{ch, rest}}:
      SCon{Char.to_upper(ch), title.go(rest)}
    case SCon{'_', SCon{ch, rest}}:
      SCon{Char.to_upper(ch), title.go(rest)}
    case SCon{'/', SCon{ch, rest}}:
      SCon{Char.to_upper(ch), title.go(rest)}
    case SCon{ch, rest}:
      SCon{ch, title.go(rest)}

# a string with its first character in upper case
def capital(text: String) -> String:
  match text:
    case SNil{}:
      SNil{}
    case SCon{ch, rest}:
      SCon{Char.to_upper(ch), rest}

def strip.lead.at(hit: Bool, ch: Char, rest: String) -> String:
  match hit:
    case True{}:
      rest
    case False{}:
      SCon{ch, rest}

def strip.lead(text: String, +want: Char) -> String:
  match text:
    case SNil{}:
      SNil{}
    case SCon{+ch, rest}:
      strip.lead.at(Char.is_eq(ch, want), ch, rest)

# a path segment in title case, as openapi-mcp-generator writes one: lower
# case, each `-`, `_` or `/` and the character after it as that character
# in upper case, less a leading `{` and a trailing `}`, the first character
# in upper case
def title(text: String) -> String:
  capital(String.reverse(strip.lead(String.reverse(
    strip.lead(title.go(String.to_lower(text)), '{')), '}')))

# whether a path segment is a template expression, `{` to `}`
def is_param(+part: String) -> Bool:
  Bool.and(String.starts_with(part, "{"), String.ends_with(part, "}"))

def segments.at(
  empty: Bool,
  part: String,
  rest: List<&2, String>
) -> List<&2, String>:
  match empty:
    case True{}:
      rest
    case False{}:
      part <> rest

# the pieces of a split path that are not empty
def segments(parts: List<&2, String>) -> List<&2, String>:
  match parts:
    case []:
      []
    case +part <> rest:
      segments.at(String.is_empty(part), part, segments(rest))

def gen.param(last: Bool, +part: String) -> String:
  match last:
    case True{}:
      "By" ++ title(part)
    case False{}:
      ""

def gen.part(param: Bool, +part: String, last: Bool) -> String:
  match param:
    case True{}:
      gen.param(last, part)
    case False{}:
      title(part)

def gen.parts(parts: List<&2, String>) -> String:
  match parts:
    case []:
      ""
    case +part <> +rest:
      gen.part(is_param(part), part, List.is_empty(&2, String, rest)) ++
        gen.parts(rest)

def gen.root(bare: Bool, +name: String) -> String:
  match bare:
    case True{}:
      name ++ "Root"
    case False{}:
      name

# an operation id made from the method and the path, for an operation with
# none, as openapi-mcp-generator makes it: the method, each path segment in
# title case, a parameter segment only when it is the last and then after
# "By", "Root" when there are no segments, the first letter in upper case
def generated(+method: String, path: String) -> String:
  +name = String.to_lower(method) ++ gen.parts(segments(String.split(path, '/')))
  capital(gen.root(String.eq(name, String.to_lower(method)), name))

# a tool's name: the operation's id when it is a non-empty string, else one
# made from the method and path (`generated`), as a tool name (`sanitize`)
def name.of(id: Maybe<&2, String>, +method: String, path: String) -> String:
  sanitize(Maybe.default(&2, String, full(id), generated(method, path)))

# a tool's description: the operation's description, else its summary,
# each when it is a non-empty string, else the method and path it runs
def describe(
  desc: Maybe<&2, String>,
  summary: Maybe<&2, String>,
  +method: String,
  path: String
) -> String:
  Maybe.default(&2, String, first(full(desc), full(summary)),
    "Executes " ++ String.to_upper(method) ++ " " ++ path)

# --- parameters (Parameter Object) ---

# whether two Parameter Objects are one parameter: the same name and the
# same location
def same(+left: Value.Json, +right: Value.Json) -> Bool:
  Bool.and(String.eq(str.at(left, "name"), str.at(right, "name")),
    String.eq(str.at(left, "in"), str.at(right, "in")))

def params.put.at(
  hit: Bool,
  old: Value.Json,
  rest: List<&2, Value.Json>,
  new: Value.Json,
  more: Unit -> List<&2, Value.Json>
) -> List<&2, Value.Json>:
  match hit:
    case True{}:
      new <> rest
    case False{}:
      old <> more(Unit{})

# parameters with `new` in the place of the first that is the same
# parameter (`same`), else last
def params.put(ps: List<&2, Value.Json>, +new: Value.Json) -> List<&2, Value.Json>:
  match ps:
    case []:
      [new]
    case +old <> +rest:
      params.put.at(same(old, new), old, rest, new, _u => params.put(rest, new))

# a Path Item's parameters `ps`, each of its operation's `ops` in turn put
# in them (`params.put`)
def params.merge(
  ops: List<&2, Value.Json>,
  ps: List<&2, Value.Json>
) -> List<&2, Value.Json>:
  match ops:
    case []:
      ps
    case one <> rest:
      params.merge(rest, params.put(ps, one))

# where a parameter goes, from its `in`
def place(+loc: String) -> Place:
  Bool.pick(Place, String.eq(loc, "path"), InPath{},
    Bool.pick(Place, String.eq(loc, "query"), InQuery{},
      Bool.pick(Place, String.eq(loc, "header"), InHeader{},
        Bool.pick(Place, String.eq(loc, "cookie"), InCookie{}, InNone{}))))

def param.of(name: Maybe<&2, String>, +loc: String) -> List<&2, Param>:
  match name:
    case None{}:
      []
    case Some{got}:
      [Param{got, place(loc)}]

# the parameters a request is built from: each with a non-empty name, and
# where it goes
def params.of(ps: List<&2, Value.Json>) -> List<&2, Param>:
  match ps:
    case []:
      []
    case +one <> rest:
      List.append(&2, Param, param.of(full(Json.as_str(Json.get(one, "name"))),
        str.at(one, "in")), params.of(rest))

# --- the input schema ---

# an input schema being built: its properties and its required names
type In is Data:
  In{props: List<&2, Mem()>, req: List<&2, String>}

def described.at(is_obj: Bool, +val: Value.Json, desc: String) -> Value.Json:
  match is_obj:
    case True{}:
      object(put(members(val), "description", Json.str(desc)))
    case False{}:
      val

# a schema with its description set to `desc`, in its place or last, when
# it is an object and there is one to set
def described(+val: Value.Json, desc: Maybe<&2, String>) -> Value.Json:
  match desc:
    case None{}:
      val
    case Some{got}:
      described.at(Json.is_obj(val), val, got)

# `name` added to the end of the required names when `want`
def need(req: List<&2, String>, name: String, want: Bool) -> List<&2, String>:
  match want:
    case True{}:
      List.append(&2, String, req, [name])
    case False{}:
      req

# whether a value stands as a schema: an object or `true`
def schema.ok(val: Value.Json) -> Bool:
  match val:
    case Value.JObj{_c}:
      True{}
    case Value.JBool{flag}:
      flag
    case other:
      False{}

def input.param.put(+name: String, +one: Value.Json, st: In) -> In:
  match st:
    case In{props, req}:
      In{put(props, name, described(schema(Json.get(one, "schema")),
        full(Json.as_str(Json.get(one, "description"))))),
        need(req, name, is_true(Json.get(one, "required")))}

# a parameter as an input property: one with a name and a schema is the
# property of that name, its schema mapped (`schema`) and described by the
# parameter's description when that is a non-empty string, and required
# when the parameter is; any other leaves the input as it is
def input.param.of(
  name: Maybe<&2, String>,
  ok: Bool,
  +one: Value.Json,
  st: In
) -> In:
  match name ok:
    case Some{+got} True{}:
      input.param.put(got, one, st)
    case _n _ok:
      st

def input.param(+one: Value.Json, st: In) -> In:
  input.param.of(full(Json.as_str(Json.get(one, "name"))),
    schema.ok(Json.get(one, "schema")), one, st)

def input.params(ps: List<&2, Value.Json>, st: In) -> In:
  match ps:
    case []:
      st
    case one <> rest:
      input.params(rest, input.param(one, st))

def media.first(ms: List<&2, Mem()>) -> String:
  match ms:
    case []:
      ""
    case (key, _v) <> _rest:
      key

def media.at(json: Bool, +content: Value.Json) -> String:
  match json:
    case True{}:
      "application/json"
    case False{}:
      media.first(members(content))

# a request body's media type: application/json when its content has a
# schema for it, else the first media type of its content, else none ("")
def media(+content: Value.Json) -> String:
  media.at(schema.ok(Json.get(Json.get(content, "application/json"), "schema")),
    content)

def body.json(+rb: Value.Json) -> Value.Json:
  +bs = schema(Json.get(Json.get(Json.get(rb, "content"), "application/json"),
    "schema"))
  described(bs, first(full(Json.as_str(Json.get(rb, "description"))),
    first(full(Json.as_str(Json.get(bs, "description"))),
      Some{"The JSON request body."})))

def body.text(+rb: Value.Json, mt: String) -> Value.Json:
  Json.obj([("type", Json.str("string")), ("description", Json.str(
    Maybe.default(&2, String, full(Json.as_str(Json.get(rb, "description"))),
      "Request body (content type: " ++ mt ++ ")")))])

def body.schema(json: Bool, +rb: Value.Json, mt: String) -> Value.Json:
  match json:
    case True{}:
      body.json(rb)
    case False{}:
      body.text(rb, mt)

def input.body.of(+rb: Value.Json, +mt: String, st: In) -> In:
  match st:
    case In{props, req}:
      In{put(props, "requestBody",
        body.schema(String.eq(mt, "application/json"), rb, mt)),
        need(req, "requestBody", is_true(Json.get(rb, "required")))}

def input.body.at(none: Bool, +rb: Value.Json, +mt: String, st: In) -> In:
  match none:
    case True{}:
      st
    case False{}:
      input.body.of(rb, mt, st)

# a Request Body Object as the `requestBody` property, with its media type
# `mt` (`media`): application/json's schema, mapped and described by the
# body's description, else the schema's, else "The JSON request body.";
# for another media type a string; required when the body is. A body of
# no media type adds nothing
def input.body(+rb: Value.Json, +mt: String, st: In) -> In:
  input.body.at(String.is_empty(mt), rb, mt, st)

# strings as JSON strings
def strs(xs: List<&2, String>) -> List<&2, Value.Json>:
  match xs:
    case []:
      []
    case str <> rest:
      Json.str(str) <> strs(rest)

# the `required` member of an input schema, none for no names
def required(req: List<&2, String>) -> List<&2, Mem()>:
  match req:
    case []:
      []
    case one <> rest:
      [("required", Json.arr(strs(one <> rest)))]

# the input schema built: an object schema of the properties, with the
# required names when there are any
def input.of(st: In) -> Value.Json:
  match st:
    case In{props, req}:
      object(List.append(&2, Mem(), [("type", Json.str("object")),
        ("properties", object(props))], required(req)))

# --- operations (Paths Object, Path Item Object, Operation Object) ---

# the methods a Path Item may have an operation for, in the order their
# tools are listed
def methods() -> List<&2, String>:
  ["get", "put", "post", "delete", "options", "head", "patch", "trace"]

# a request body's media type, "" for none
def media.of(+rb: Value.Json, has: Bool) -> String:
  match has:
    case True{}:
      media(Json.get(rb, "content"))
    case False{}:
      ""

# one operation of a Path Item at `path`, `oper` its Operation Object, its
# references followed in `doc`, after the Path Item's parameters `ips`
def op(
  +doc: Value.Json,
  +path: String,
  +method: String,
  ips: List<&2, Value.Json>,
  +oper: Value.Json
) -> Op:
  +ps = params.merge(Json.items(dereferenced(doc,
    Json.get(oper, "parameters"))), ips)
  +rb = dereferenced(doc, Json.get(oper, "requestBody"))
  +mt = media.of(rb, Json.is_obj(rb))
  Op{name.of(Json.as_str(Json.get(oper, "operationId")), method, path),
    describe(Json.as_str(Json.get(oper, "description")),
      Json.as_str(Json.get(oper, "summary")), method, path),
    input.of(input.body(rb, mt, input.params(ps, In{[], []}))),
    String.to_upper(method), path, params.of(ps), mt}

def item.at(
  hit: Bool,
  +doc: Value.Json,
  +path: String,
  +method: String,
  +ips: List<&2, Value.Json>,
  +oper: Value.Json,
  rest: List<&2, Op>
) -> List<&2, Op>:
  match hit:
    case True{}:
      op(doc, path, method, ips, oper) <> rest
    case False{}:
      rest

# a Path Item's operations for the methods `ms`, in their order: one for
# each method whose member is an object (`op`), none for any other
def item(
  ms: List<&2, String>,
  +doc: Value.Json,
  +path: String,
  +it: Value.Json,
  +ips: List<&2, Value.Json>
) -> List<&2, Op>:
  match ms:
    case []:
      []
    case +method <> rest:
      +oper = Json.get(it, method)
      item.at(Json.is_obj(oper), doc, path, method, ips, oper,
        item(rest, doc, path, it, ips))

# the operations of the Path Items `ps`, in order, each one's in the order
# of `methods`, after its parameters with their references followed
def paths(ps: List<&2, Mem()>, +doc: Value.Json) -> List<&2, Op>:
  match ps:
    case []:
      []
    case (+path, +it) <> rest:
      List.append(&2, Op, item(methods(), doc, path, it,
        Json.items(dereferenced(doc, Json.get(it, "parameters")))),
        paths(rest, doc))

# every operation of a document, in the order of its paths (`paths`)
def ops(+doc: Value.Json) -> List<&2, Op>:
  paths(members(Json.get(doc, "paths")), doc)

# an operation's tool
def tool(oper: Op) -> Server.Tool:
  match oper:
    case Op{name, description, input, method, path, params, media}:
      Server.Tool{name, description, input}

# an operation's tool name
def name(oper: Op) -> String:
  match oper:
    case Op{got, description, input, method, path, params, media}:
      got

# an operation under another tool name, all else as it was
def renamed(oper: Op, to: String) -> Op:
  match oper:
    case Op{name, description, input, method, path, params, media}:
      Op{to, description, input, method, path, params, media}

# --- calls ---

def arg.at(has: Bool, +val: Value.Json) -> Maybe<&2, Value.Json>:
  match has:
    case True{}:
      Bool.pick(Maybe<&2, Value.Json>, is_null(val), None{}, Some{val})
    case False{}:
      None{}

# an argument's value when it is there and not null
def arg(+args: Value.Json, +name: String) -> Maybe<&2, Value.Json>:
  arg.at(Json.has(args, name), Json.get(args, name))

def plain.scalar(val: Value.Json) -> String:
  match val:
    case Value.JStr{str}:
      str
    case Value.JSpan{src, +n}:
      Value.span.str(src, n, U32.is_zero(n))
    case Value.JNum{raw}:
      raw
    case Value.JBool{True{}}:
      "true"
    case Value.JBool{False{}}:
      "false"
    case other:
      Json.print(other)

def plain.item(val: Value.Json) -> String:
  match val:
    case Value.JNull{}:
      ""
    case other:
      plain.scalar(other)

def plain.items(items: List<&2, Value.Json>) -> List<&2, String>:
  match items:
    case []:
      []
    case one <> rest:
      plain.item(one) <> plain.items(rest)

# a value as the text of a parameter: a string as itself, a number as its
# text, a boolean as `true` or `false`, an array as its items' texts joined
# by `,` (style simple), anything else as its JSON
def plain(val: Value.Json) -> String:
  match val:
    case Value.JArr{+cs}:
      String.join(plain.items(Json.items(Value.JArr{cs})), ",")
    case other:
      plain.scalar(other)

def swap.at(
  hit: Bool,
  +text: String,
  +pat: String,
  rep: String,
  more: Unit -> String
) -> String:
  match hit:
    case True{}:
      rep ++ String.drop(text, String.length(pat))
    case False{}:
      more(Unit{})

# a string with its first `pat` replaced by `rep`
def swap(text: String, +pat: String, +rep: String) -> String:
  match text:
    case SNil{}:
      SNil{}
    case SCon{+ch, +rest}:
      swap.at(String.starts_with(SCon{ch, rest}, pat), SCon{ch, rest}, pat, rep,
        _u => SCon{ch, swap(rest, pat, rep)})

# a path template with its first `{name}` replaced by the value's text,
# percent-encoded as a path segment
def fill(path: String, +name: String, val: Value.Json) -> String:
  swap(path, "{" ++ name ++ "}", Pct.quote(False{}, plain(val)))

def query.item(+name: String, val: Value.Json) -> List<&2, Qs.Kv()>:
  match val:
    case Value.JNull{}:
      []
    case other:
      [(name, plain.scalar(other))]

def query.items(+name: String, items: List<&2, Value.Json>) -> List<&2, Qs.Kv()>:
  match items:
    case []:
      []
    case one <> rest:
      List.append(&2, Qs.Kv(), query.item(name, one), query.items(name, rest))

# a query parameter's pairs: one for each item of an array that is not
# null, else one of the value's text (style form, explode true)
def query(+name: String, val: Value.Json) -> List<&2, Qs.Kv()>:
  match val:
    case Value.JArr{+cs}:
      query.items(name, Json.items(Value.JArr{cs}))
    case other:
      [(name, plain(other))]

# a request being built: the path, the query's pairs and the header fields
type Req is Data:
  Req{path: String, query: List<&2, Qs.Kv()>, headers: List<&2, Http.Header>}

# a parameter's value put in a request: a path parameter filled into the
# path (`fill`), a query parameter's pairs added to the query (`query`), a
# header parameter a header field of its name in lower case and its text
# (`plain`); a cookie parameter, or one of no known location, changes
# nothing
def req.put.at(
  place: Place,
  +name: String,
  val: Value.Json,
  path: String,
  pairs: List<&2, Qs.Kv()>,
  hs: List<&2, Http.Header>
) -> Req:
  match place:
    case InPath{}:
      Req{fill(path, name, val), pairs, hs}
    case InQuery{}:
      Req{path, List.append(&2, Qs.Kv(), pairs, query(name, val)), hs}
    case InHeader{}:
      Req{path, pairs, List.append(&2, Http.Header, hs,
        [Http.H{String.to_lower(name), plain(val)}])}
    case InCookie{}:
      Req{path, pairs, hs}
    case InNone{}:
      Req{path, pairs, hs}

def req.put(place: Place, +name: String, val: Value.Json, sofar: Req) -> Req:
  match sofar:
    case Req{path, pairs, hs}:
      req.put.at(place, name, val, path, pairs, hs)

def req.arg(
  got: Maybe<&2, Value.Json>,
  place: Place,
  +name: String,
  sofar: Req
) -> Req:
  match got:
    case None{}:
      sofar
    case Some{val}:
      req.put(place, name, val, sofar)

# a request with each parameter that has an argument there and not null
# put in it (`req.put`), in order
def req.params(ps: List<&2, Param>, +args: Value.Json, sofar: Req) -> Req:
  match ps:
    case []:
      sofar
    case Param{+name, place} <> rest:
      req.params(rest, args, req.arg(arg(args, name), place, name, sofar))

def body.text.of(json: Bool, val: Value.Json) -> String:
  match json:
    case True{}:
      Json.print(val)
    case False{}:
      plain.scalar(val)

def body.of(+mt: String, got: Maybe<&2, Value.Json>) -> Maybe<&2, String>:
  match got:
    case None{}:
      None{}
    case Some{val}:
      Some{body.text.of(String.eq(mt, "application/json"), val)}

# a request's body: the `requestBody` argument, when the operation has a
# body and the argument is there and not null, as JSON for
# application/json, else a string as itself and anything else as its JSON
def body.arg(none: Bool, +mt: String, +args: Value.Json) -> Maybe<&2, String>:
  match none:
    case True{}:
      None{}
    case False{}:
      body.of(mt, arg(args, "requestBody"))

# the header field naming a body's media type, when there is a body
def ctype(+mt: String, body: Maybe<&2, String>) -> List<&2, Http.Header>:
  match body:
    case None{}:
      []
    case Some{_b}:
      [Http.H{"Content-Type", mt}]

# a query string: none for no pairs, else `?` and the pairs form-encoded
def query.text(pairs: List<&2, Qs.Kv()>) -> String:
  match pairs:
    case []:
      ""
    case one <> rest:
      "?" ++ Qs.urlencode(one <> rest)

# the request built, or the path when a template expression is still in it
def call.send(
  unfilled: Bool,
  method: String,
  +mt: String,
  +body: Maybe<&2, String>,
  path: String,
  pairs: List<&2, Qs.Kv()>,
  hs: List<&2, Http.Header>
) -> Call:
  match unfilled:
    case True{}:
      Unfilled{path}
    case False{}:
      Send{method, path ++ query.text(pairs), List.append(&2, Http.Header,
        Http.H{"Accept", "application/json"} <> hs, ctype(mt, body)), body}

def call.of(
  method: String,
  +mt: String,
  +body: Maybe<&2, String>,
  built: Req
) -> Call:
  match built:
    case Req{+path, pairs, hs}:
      call.send(String.contains(path, "{"), method, mt, body, path, pairs, hs)

# the request a call of an operation stands for, with these arguments:
# each parameter with an argument there and not null put in the request
# (`req.params`), the header fields Accept: application/json, then the
# header parameters', then Content-Type when there is a body (`body.arg`);
# or Unfilled when the path still holds a `{`
def call(oper: Op, +args: Value.Json) -> Call:
  match oper:
    case Op{name, description, input, method, path, params, +mt}:
      call.of(method, mt, body.arg(String.is_empty(mt), mt, args),
        req.params(params, args, Req{path, [], []}))

# --- checking a call's arguments ---

# whether every character is a digit
def digits(text: String) -> Bool:
  match text:
    case SNil{}:
      True{}
    case SCon{ch, rest}:
      and.then(Char.is_digit(ch), _u => digits(rest))

# whether a number's text is an integer: an optional `-`, then digits
def int.text(text: String) -> Bool:
  match text:
    case SNil{}:
      False{}
    case SCon{'-', +rest}:
      Bool.and(Bool.not(String.is_empty(rest)), digits(rest))
    case SCon{ch, rest}:
      digits(SCon{ch, rest})

def kind.int(val: Value.Json) -> Bool:
  match val:
    case Value.JNum{raw}:
      int.text(raw)
    case other:
      False{}

def kind.str(val: Value.Json) -> Bool:
  match val:
    case Value.JStr{_s}:
      True{}
    case Value.JSpan{_src, _n}:
      True{}
    case other:
      False{}

def kind.num(val: Value.Json) -> Bool:
  match val:
    case Value.JNum{_raw}:
      True{}
    case other:
      False{}

def kind.bool(val: Value.Json) -> Bool:
  match val:
    case Value.JBool{_b}:
      True{}
    case other:
      False{}

# the JSON type of a value, as JSON Schema names it
def kind.name(val: Value.Json) -> String:
  match val:
    case Value.JNull{}:
      "null"
    case Value.JBool{_b}:
      "boolean"
    case Value.JNum{_r}:
      "number"
    case Value.JStr{_s}:
      "string"
    case Value.JSpan{_src, _n}:
      "string"
    case Value.JArr{_c}:
      "array"
    case Value.JObj{_c}:
      "object"
    case other:
      "unknown"

# whether a value is of the JSON Schema type named `typ`: string, number,
# integer (a number whose text is an integer), boolean, array, object or
# null; true for a name JSON Schema does not have
def kind(+typ: String, +val: Value.Json) -> Bool:
  +int = kind.int(val)
  Bool.pick(Bool, String.eq(typ, "integer"), int,
    Bool.pick(Bool, String.eq(typ, "string"), kind.str(val),
      Bool.pick(Bool, String.eq(typ, "number"), kind.num(val),
        Bool.pick(Bool, String.eq(typ, "boolean"), kind.bool(val),
          Bool.pick(Bool, String.eq(typ, "array"), Json.is_arr(val),
            Bool.pick(Bool, String.eq(typ, "object"), Json.is_obj(val),
              Bool.pick(Bool, String.eq(typ, "null"), is_null(val), True{})))))))

# whether a value is of one of the types an array of names lists
def kinds(types: List<&2, Value.Json>, +val: Value.Json) -> Bool:
  match types:
    case []:
      False{}
    case one <> rest:
      or.else(kind(Maybe.default(&2, String, Json.as_str(one), ""), val),
        _u => kinds(rest, val))

# whether a value is of a schema's `type`: the type it names, or one of the
# types an array of names lists; true for a schema with no `type`
def typed(typ: Value.Json, +val: Value.Json) -> Bool:
  match typ:
    case Value.JStr{str}:
      kind(str, val)
    case Value.JSpan{src, +n}:
      kind(Value.span.str(src, n, U32.is_zero(n)), val)
    case Value.JArr{+cs}:
      kinds(Json.items(Value.JArr{cs}), val)
    case other:
      True{}

# whether a value is of one of the `anyOf` alternatives' types
def alts(choices: List<&2, Value.Json>, +val: Value.Json) -> Bool:
  match choices:
    case []:
      False{}
    case one <> rest:
      or.else(typed(Json.get(one, "type"), val), _u => alts(rest, val))

def same.json(+val: Value.Json, items: List<&2, Value.Json>) -> Bool:
  match items:
    case []:
      False{}
    case one <> rest:
      or.else(String.eq(Json.print(one), Json.print(val)),
        _u => same.json(val, rest))

# whether a value fits a property's schema, one level deep: its `type`
# (`typed`), one of its `anyOf` alternatives' types when it has `anyOf`,
# and one of its `enum` values when it has `enum`
def fits(+sch: Value.Json, +val: Value.Json) -> Bool:
  +any = Json.get(sch, "anyOf")
  +en = Json.get(sch, "enum")
  Bool.and(typed(Json.get(sch, "type"), val),
    Bool.and(Bool.or(Bool.not(Json.is_arr(any)), alts(Json.items(any), val)),
      Bool.or(Bool.not(Json.is_arr(en)), same.json(val, Json.items(en)))))

def missing.at(
  has: Bool,
  name: String,
  more: Unit -> Maybe<&2, String>
) -> Maybe<&2, String>:
  match has:
    case True{}:
      more(Unit{})
    case False{}:
      Some{name ++ ": Required"}

# what the first required name the arguments do not have is missing
def missing(req: List<&2, Value.Json>, +args: Value.Json) -> Maybe<&2, String>:
  match req:
    case []:
      None{}
    case one <> rest:
      +name = Maybe.default(&2, String, Json.as_str(one), "")
      missing.at(Json.has(args, name), name, _u => missing(rest, args))

def wanted.of(typ: Maybe<&2, String>, val: Value.Json) -> String:
  match typ:
    case Some{str}:
      "Expected " ++ str ++ ", received " ++ kind.name(val)
    case None{}:
      "Invalid input"

# what is wrong with a value that does not fit its schema: the type it
# should have had, when the schema names one, and the type it has
def wanted(sch: Value.Json, val: Value.Json) -> String:
  wanted.of(Json.as_str(Json.get(sch, "type")), val)

def bad.at(
  ok: Bool,
  name: String,
  sch: Value.Json,
  val: Value.Json,
  more: Unit -> Maybe<&2, String>
) -> Maybe<&2, String>:
  match ok:
    case True{}:
      more(Unit{})
    case False{}:
      Some{name ++ ": " ++ wanted(sch, val)}

# what is wrong with the first property whose argument is there and does
# not fit its schema (`fits`)
def bad(ps: List<&2, Mem()>, +args: Value.Json) -> Maybe<&2, String>:
  match ps:
    case []:
      None{}
    case (+name, +sch) <> rest:
      bad.at(Bool.or(Bool.not(Json.has(args, name)), fits(sch, Json.get(args,
        name))), name, sch, Json.get(args, name), _u => bad(rest, args))

def check.of(name: String, why: Maybe<&2, String>) -> Maybe<&2, String>:
  match why:
    case None{}:
      None{}
    case Some{got}:
      Some{"Invalid arguments for tool '" ++ name ++ "': " ++ got}

# what is wrong with a call's arguments, when anything is: a required name
# they do not have (`missing`), else a property they have whose value does
# not fit its schema (`bad`); none when neither
def check(oper: Op, +args: Value.Json) -> Maybe<&2, String>:
  match oper:
    case Op{name, description, +input, method, path, params, media}:
      check.of(name, first(missing(Json.items(Json.get(input, "required")),
        args), bad(members(Json.get(input, "properties")), args)))
