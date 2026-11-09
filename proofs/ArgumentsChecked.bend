# proofs of laws/ArgumentsChecked.bend
import Base
import ezjson@1.2.0.0/main.bend as Json
import ../src/openapi.bend as Openapi
import ../laws/ArgumentsChecked.bend as Laws

def Laws.oas_check(_name, _description, _input, _method, _path, _params, _media, _args):
  {==}

def Laws.oas_check_ok(_name):
  {==}

def Laws.oas_check_why(_name, _why):
  {==}

def Laws.oas_missing_none(_args):
  {==}

def Laws.oas_missing_hit(name, rest, args, e):
  f = Equal.sym(Bool, Json.has(args, name), False{}, e)
  %f : {Openapi.missing.at(_, name, _u => Openapi.missing(rest, args))
    == Some{name ++ ": Required"} : Maybe<&2, String>}
  {==}

def Laws.oas_typed_any(_val):
  {==}

def Laws.oas_kind_string(_str):
  {==}

def Laws.oas_kind_number_text(_raw):
  {==}
