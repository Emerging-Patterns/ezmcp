# proofs of laws/CallsBuildRequests.bend
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ezhttp@0.23.0.0/src/http.bend as Http
import ../src/openapi.bend as Openapi
import ../laws/CallsBuildRequests.bend as Laws
import ./lemmas/BoolCharStringFacts.bend as M1

def Laws.oas_call(_name, _description, _input, _method, _path, _params, _mt, _args):
  {==}

def Laws.oas_req_path(_name, _val, _path, _pairs, _hs):
  {==}

def Laws.oas_req_query(_name, _val, _path, _pairs, _hs):
  {==}

def Laws.oas_req_header(_name, _val, _path, _pairs, _hs):
  {==}

def Laws.oas_req_cookie(_name, _val, _path, _pairs, _hs):
  {==}

def Laws.oas_req_absent(_place, _name, _sofar):
  {==}

def Laws.oas_arg_absent(args, name, e):
  f = Equal.sym(Bool, Json.has(args, name), False{}, e)
  %f : {Openapi.arg.at(_, Json.get(args, name)) == None{} : Maybe<&2, Value.Json>}
  {==}

def Laws.oas_arg_null(args, name, eh, en):
  fh = Equal.sym(Bool, Json.has(args, name), True{}, eh)
  fn = Equal.sym(Value.Json, Json.get(args, name), Value.JNull{}, en)
  %fh : {Openapi.arg.at(_, Json.get(args, name)) == None{} : Maybe<&2, Value.Json>}
  %fn : {Openapi.arg.at(True{}, _) == None{} : Maybe<&2, Value.Json>}
  {==}

def Laws.oas_query_array(_name, _cs):
  {==}

def Laws.oas_query_null(_name, _rest):
  {==}

def Laws.oas_query_str(_name, _str):
  {==}

def Laws.oas_plain_num(_raw):
  {==}

def Laws.oas_unfilled(method, mt, body, path, pairs, hs, e):
  f = Equal.sym(Bool, String.contains(path, "{"), True{}, e)
  %f : {Openapi.call.send(_, method, mt, body, path, pairs, hs)
    == Openapi.Unfilled{path} : Openapi.Call}
  {==}

def Laws.oas_send(method, mt, body, path, pairs, hs, e):
  f = Equal.sym(Bool, String.contains(path, "{"), False{}, e)
  %f : {Openapi.call.send(_, method, mt, body, path, pairs, hs)
    == Openapi.Send{method, path ++ Openapi.query.text(pairs), List.append(&2,
      Http.Header, Http.H{"Accept", "application/json"} <> hs, Openapi.ctype(mt,
      body)), body} : Openapi.Call}
  {==}

def Laws.oas_query_text_none(pairs, e):
  match pairs:
    case []:
      {==}
    case one <> rest:
      M1.absurd(&2, {Openapi.query.text(one <> rest) == "" : String}, e)

def Laws.oas_body_absent(_mt, _args):
  {==}

def Laws.oas_body_sent(_val):
  {==}

def Laws.oas_ctype_none(_mt):
  {==}

def Laws.oas_ctype_body(_mt, _body):
  {==}
