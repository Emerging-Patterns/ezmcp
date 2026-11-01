# proofs of laws/ParametersBecomeProperties.bend
import Base
import ../src/openapi.bend as Openapi
import ../laws/ParametersBecomeProperties.bend as Laws

def Laws.oas_param_put(_name, _one, _props, _req):
  {==}

def Laws.oas_param_unnamed(_ok, _one, _st):
  {==}

def Laws.oas_param_unschemed(name, _one, _st):
  match name:
    case None{}:
      {==}
    case Some{_got}:
      {==}

def Laws.oas_need(_req, _name):
  {==}

def Laws.oas_need_not(_req, _name):
  {==}

def Laws.oas_put_last(_key, _val):
  {==}

def Laws.oas_put_hit(k2, v2, rest, key, val, e):
  f = Equal.sym(Bool, String.eq(k2, key), True{}, e)
  %f : {Openapi.put.at(_, k2, v2, rest, key, val, _u => Openapi.put(rest, key,
    val)) == (key, val) <> rest : List<&2, Openapi.Mem()>}
  {==}

def Laws.oas_put_miss(k2, v2, rest, key, val, e):
  f = Equal.sym(Bool, String.eq(k2, key), False{}, e)
  %f : {Openapi.put.at(_, k2, v2, rest, key, val, _u => Openapi.put(rest, key,
    val)) == (k2, v2) <> Openapi.put(rest, key, val) : List<&2, Openapi.Mem()>}
  {==}

def Laws.oas_described(_cs, _desc):
  {==}

def Laws.oas_described_none(_val):
  {==}
