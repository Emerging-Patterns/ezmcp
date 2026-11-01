# `oas/v3.1.0#reference-object`: `$ref` is "REQUIRED. The reference
# identifier. This MUST be in the form of a URI"; description "A description
# which by default SHOULD override that of the referenced component"; RFC
# 6901 §4: "first transforming any occurrence of the sequence '~1' to '/',
# and then transforming any occurrence of the sequence '~0' to '~'". In a
# Path Item's and an operation's parameters and in a request body, an object
# whose `$ref` is a local reference (`#/` and a JSON Pointer, each token
# decoded) that resolves is its target, the target's own references followed
# in turn, with the object's other members first and the target's members
# they do not name after them; a reference to one being followed (a cycle)
# is `{"type": "object"}`; a reference that is not local or does not resolve
# leaves the object as it is
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/openapi.bend as Openapi

# LAW: `~1` is `/`
law oas_token_slash:
  for rest: String
  {Openapi.token(SCon{'~', SCon{'1', rest}}) == SCon{'/', Openapi.token(rest)}
    : String}

# LAW: `~0` is `~`
law oas_token_tilde:
  for rest: String
  {Openapi.token(SCon{'~', SCon{'0', rest}}) == SCon{'~', Openapi.token(rest)}
    : String}

# LAW: a local reference is walked from the document
law oas_resolve_local:
  for +doc: Value.Json
  for +ref: String
  for e: {String.starts_with(ref, "#/") == True{} : Bool}
  {Openapi.resolve(doc, ref)
    == Openapi.walk(String.split(String.drop(ref, 2n), '/'), doc)
    : Maybe<&2, Value.Json>}

# LAW: any other resolves to nothing
law oas_resolve_other:
  for +doc: Value.Json
  for +ref: String
  for e: {String.starts_with(ref, "#/") == False{} : Bool}
  {Openapi.resolve(doc, ref) == None{} : Maybe<&2, Value.Json>}

# LAW: a walk with no tokens left is where it is
law oas_walk_done:
  for +val: Value.Json
  {Openapi.walk([], val) == Some{val} : Maybe<&2, Value.Json>}

# LAW: a token the value has no member of resolves to nothing
law oas_walk_miss:
  for +tok: String
  for rest: List<&2, String>
  for +val: Value.Json
  for e: {Json.has(val, Openapi.token(tok)) == False{} : Bool}
  {Openapi.walk(tok <> rest, val) == None{} : Maybe<&2, Value.Json>}

# LAW: a reference with no other members is its target
law oas_merge_bare:
  for +target: Value.Json
  {Openapi.merge([], target) == target : Value.Json}

# LAW: else its members come first, then the target's
law oas_merge_sib:
  for +one: Openapi.Mem()
  for +rest: List<&2, Openapi.Mem()>
  for +target: Value.Json
  {Openapi.merge(one <> rest, target)
    == Openapi.object(Openapi.merge.add(Openapi.members(target), one <> rest))
    : Value.Json}

# LAW: a target member they name is left out
law oas_merge_add_hit:
  for +key: String
  for val: Value.Json
  for rest: List<&2, Openapi.Mem()>
  for +sib: List<&2, Openapi.Mem()>
  for e: {Openapi.named(sib, key) == True{} : Bool}
  {Openapi.merge.add((key, val) <> rest, sib) == Openapi.merge.add(rest, sib)
    : List<&2, Openapi.Mem()>}

# LAW: any other is added after them
law oas_merge_add_miss:
  for +key: String
  for val: Value.Json
  for rest: List<&2, Openapi.Mem()>
  for +sib: List<&2, Openapi.Mem()>
  for e: {Openapi.named(sib, key) == False{} : Bool}
  {Openapi.merge.add((key, val) <> rest, sib)
    == Openapi.merge.add(rest, List.append(&2, Openapi.Mem(), sib, [(key, val)]))
    : List<&2, Openapi.Mem()>}

# LAW: a reference to one being followed is a cycle
law oas_deref_cycle:
  for +less: Nat
  for +pairs: Value.Json
  for +doc: Value.Json
  for +refs: List<&2, String>
  for +ref: String
  for er: {Openapi.ref.of(pairs) == Some{ref} : Maybe<&2, String>}
  for es: {Openapi.seen(refs, ref) == True{} : Bool}
  {Openapi.deref(1n+less, Value.JObj{pairs}, doc, refs) == Openapi.cyclic()
    : Value.Json}

# LAW: an object with no reference has its values followed
law oas_deref_plain:
  for +less: Nat
  for +pairs: Value.Json
  for +doc: Value.Json
  for +refs: List<&2, String>
  for er: {Openapi.ref.of(pairs) == None{} : Maybe<&2, String>}
  {Openapi.deref(1n+less, Value.JObj{pairs}, doc, refs)
    == Value.JObj{Openapi.deref(1n+less, pairs, doc, refs)} : Value.Json}

# LAW: a reference that resolves is its target, followed, merged
law oas_deref_follow:
  for +less: Nat
  for +pairs: Value.Json
  for +doc: Value.Json
  for +refs: List<&2, String>
  for +ref: String
  for +target: Value.Json
  for er: {Openapi.ref.of(pairs) == Some{ref} : Maybe<&2, String>}
  for es: {Openapi.seen(refs, ref) == False{} : Bool}
  for et: {Openapi.resolve(doc, ref) == Some{target} : Maybe<&2, Value.Json>}
  {Openapi.deref(1n+less, Value.JObj{pairs}, doc, refs)
    == Openapi.merge(Openapi.drop(Openapi.members(Value.JObj{Openapi.deref(1n+less,
      pairs, doc, refs)}), "$ref"), Openapi.deref(less, target, doc, ref <> refs))
    : Value.Json}

# LAW: one that does not is left as it is
law oas_deref_lost:
  for +less: Nat
  for +pairs: Value.Json
  for +doc: Value.Json
  for +refs: List<&2, String>
  for +ref: String
  for er: {Openapi.ref.of(pairs) == Some{ref} : Maybe<&2, String>}
  for es: {Openapi.seen(refs, ref) == False{} : Bool}
  for et: {Openapi.resolve(doc, ref) == None{} : Maybe<&2, Value.Json>}
  {Openapi.deref(1n+less, Value.JObj{pairs}, doc, refs)
    == Value.JObj{Openapi.deref(1n+less, pairs, doc, refs)} : Value.Json}
