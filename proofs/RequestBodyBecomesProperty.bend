# proofs of laws/RequestBodyBecomesProperty.bend
import Base
import ezjson@1.2.0.0/main.bend as Json
import ../src/openapi.bend as Openapi
import ../laws/RequestBodyBecomesProperty.bend as Laws
import ./lemmas/BoolCharStringFacts.bend as M1

def Laws.oas_media_json(content, e):
  f = Equal.sym(Bool, Openapi.schema.ok(Json.get(Json.get(content,
    "application/json"), "schema")), True{}, e)
  %f : {Openapi.media.at(_, content) == "application/json" : String}
  {==}

def Laws.oas_media_other(content, e):
  f = Equal.sym(Bool, Openapi.schema.ok(Json.get(Json.get(content,
    "application/json"), "schema")), False{}, e)
  %f : {Openapi.media.at(_, content)
    == Openapi.media.first(Openapi.members(content)) : String}
  {==}

def Laws.oas_body_none(_rb, _st):
  {==}

def Laws.oas_body_json(_rb, _props, _req):
  {==}

def Laws.oas_body_text(rb, mt, props, req, none, json):
  f1 = Equal.sym(Bool, String.is_empty(mt), False{}, none)
  f2 = Equal.sym(Bool, String.eq(mt, "application/json"), False{}, json)
  %f1 : {Openapi.input.body.at(_, rb, mt, Openapi.In{props, req})
    == Openapi.In{Openapi.put(props, "requestBody", Openapi.body.text(rb, mt)),
      Openapi.need(req, "requestBody", Openapi.is_true(Json.get(rb,
      "required")))} : Openapi.In}
  %f2 : {Openapi.In{Openapi.put(props, "requestBody", Openapi.body.schema(_, rb,
    mt)), Openapi.need(req, "requestBody", Openapi.is_true(Json.get(rb,
    "required")))}
    == Openapi.In{Openapi.put(props, "requestBody", Openapi.body.text(rb, mt)),
      Openapi.need(req, "requestBody", Openapi.is_true(Json.get(rb,
      "required")))} : Openapi.In}
  {==}

def Laws.oas_input(_props, _req):
  {==}

def Laws.oas_required_none(req, e):
  match req:
    case []:
      {==}
    case one <> rest:
      M1.absurd(&2, {Openapi.required(one <> rest) == [] : List<&2, Openapi.Mem()>}, e)

def Laws.oas_required_some(_one, _rest):
  {==}
