# proofs of laws/LocalRefsResolved.bend
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/openapi.bend as Openapi
import ../laws/LocalRefsResolved.bend as Laws

def Laws.oas_token_slash(_rest):
  {==}

def Laws.oas_token_tilde(_rest):
  {==}

def Laws.oas_resolve_local(doc, ref, e):
  f = Equal.sym(Bool, String.starts_with(ref, "#/"), True{}, e)
  %f : {Openapi.resolve.at(_, doc, ref)
    == Openapi.walk(String.split(String.drop(ref, 2n), '/'), doc)
    : Maybe<&2, Value.Json>}
  {==}

def Laws.oas_resolve_other(doc, ref, e):
  f = Equal.sym(Bool, String.starts_with(ref, "#/"), False{}, e)
  %f : {Openapi.resolve.at(_, doc, ref) == None{} : Maybe<&2, Value.Json>}
  {==}

def Laws.oas_walk_done(_val):
  {==}

def Laws.oas_walk_miss(tok, rest, val, e):
  f = Equal.sym(Bool, Json.has(val, Openapi.token(tok)), False{}, e)
  %f : {Openapi.walk.at(_, Json.get(val, Openapi.token(tok)),
    got => Openapi.walk(rest, got)) == None{} : Maybe<&2, Value.Json>}
  {==}

def Laws.oas_merge_bare(_target):
  {==}

def Laws.oas_merge_sib(_one, _rest, _target):
  {==}

def Laws.oas_merge_add_hit(key, val, rest, sib, e):
  f = Equal.sym(Bool, Openapi.named(sib, key), True{}, e)
  %f : {Openapi.merge.add(rest, Openapi.merge.one(_, sib, key, val))
    == Openapi.merge.add(rest, sib) : List<&2, Openapi.Mem()>}
  {==}

def Laws.oas_merge_add_miss(key, val, rest, sib, e):
  f = Equal.sym(Bool, Openapi.named(sib, key), False{}, e)
  %f : {Openapi.merge.add(rest, Openapi.merge.one(_, sib, key, val))
    == Openapi.merge.add(rest, List.append(&2, Openapi.Mem(), sib, [(key, val)]))
    : List<&2, Openapi.Mem()>}
  {==}

def Laws.oas_deref_cycle(less, pairs, doc, refs, ref, er, es):
  fr = Equal.sym(Maybe<&2, String>, Openapi.ref.of(pairs), Some{ref}, er)
  fs = Equal.sym(Bool, Openapi.seen(refs, ref), True{}, es)
  %fr : {Openapi.deref.obj(_, doc, refs,
    _u => Value.JObj{Openapi.deref(1n+less, pairs, doc, refs)},
    got => target => Openapi.deref(less, target, doc, got <> refs))
    == Openapi.cyclic() : Value.Json}
  %fs : {Openapi.deref.ref(_, ref, doc,
    _u => Value.JObj{Openapi.deref(1n+less, pairs, doc, refs)},
    got => target => Openapi.deref(less, target, doc, got <> refs))
    == Openapi.cyclic() : Value.Json}
  {==}

def Laws.oas_deref_plain(less, pairs, doc, refs, er):
  fr = Equal.sym(Maybe<&2, String>, Openapi.ref.of(pairs), None{}, er)
  %fr : {Openapi.deref.obj(_, doc, refs,
    _u => Value.JObj{Openapi.deref(1n+less, pairs, doc, refs)},
    got => target => Openapi.deref(less, target, doc, got <> refs))
    == Value.JObj{Openapi.deref(1n+less, pairs, doc, refs)} : Value.Json}
  {==}

def Laws.oas_deref_follow(less, pairs, doc, refs, ref, target, er, es, et):
  fr = Equal.sym(Maybe<&2, String>, Openapi.ref.of(pairs), Some{ref}, er)
  fs = Equal.sym(Bool, Openapi.seen(refs, ref), False{}, es)
  ft = Equal.sym(Maybe<&2, Value.Json>, Openapi.resolve(doc, ref), Some{target},
    et)
  %fr : {Openapi.deref.obj(_, doc, refs,
    _u => Value.JObj{Openapi.deref(1n+less, pairs, doc, refs)},
    got => tg => Openapi.deref(less, tg, doc, got <> refs))
    == Openapi.merge(Openapi.drop(Openapi.members(Value.JObj{Openapi.deref(1n+less,
      pairs, doc, refs)}), "$ref"), Openapi.deref(less, target, doc, ref <> refs))
    : Value.Json}
  %fs : {Openapi.deref.ref(_, ref, doc,
    _u => Value.JObj{Openapi.deref(1n+less, pairs, doc, refs)},
    got => tg => Openapi.deref(less, tg, doc, got <> refs))
    == Openapi.merge(Openapi.drop(Openapi.members(Value.JObj{Openapi.deref(1n+less,
      pairs, doc, refs)}), "$ref"), Openapi.deref(less, target, doc, ref <> refs))
    : Value.Json}
  %ft : {Openapi.deref.found(_,
    _u => Value.JObj{Openapi.deref(1n+less, pairs, doc, refs)},
    tg => Openapi.deref(less, tg, doc, ref <> refs))
    == Openapi.merge(Openapi.drop(Openapi.members(Value.JObj{Openapi.deref(1n+less,
      pairs, doc, refs)}), "$ref"), Openapi.deref(less, target, doc, ref <> refs))
    : Value.Json}
  {==}

def Laws.oas_deref_lost(less, pairs, doc, refs, ref, er, es, et):
  fr = Equal.sym(Maybe<&2, String>, Openapi.ref.of(pairs), Some{ref}, er)
  fs = Equal.sym(Bool, Openapi.seen(refs, ref), False{}, es)
  ft = Equal.sym(Maybe<&2, Value.Json>, Openapi.resolve(doc, ref), None{}, et)
  %fr : {Openapi.deref.obj(_, doc, refs,
    _u => Value.JObj{Openapi.deref(1n+less, pairs, doc, refs)},
    got => tg => Openapi.deref(less, tg, doc, got <> refs))
    == Value.JObj{Openapi.deref(1n+less, pairs, doc, refs)} : Value.Json}
  %fs : {Openapi.deref.ref(_, ref, doc,
    _u => Value.JObj{Openapi.deref(1n+less, pairs, doc, refs)},
    got => tg => Openapi.deref(less, tg, doc, got <> refs))
    == Value.JObj{Openapi.deref(1n+less, pairs, doc, refs)} : Value.Json}
  %ft : {Openapi.deref.found(_,
    _u => Value.JObj{Openapi.deref(1n+less, pairs, doc, refs)},
    tg => Openapi.deref(less, tg, doc, ref <> refs))
    == Value.JObj{Openapi.deref(1n+less, pairs, doc, refs)} : Value.Json}
  {==}
