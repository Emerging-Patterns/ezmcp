# proofs of laws/DescriptionsFromOperations.bend
import Base
import ../src/openapi.bend as Openapi
import ../laws/DescriptionsFromOperations.bend as Laws

def Laws.oas_describe_desc(desc, summary, method, path, e):
  f = Equal.sym(Bool, String.is_empty(desc), False{}, e)
  %f : {Maybe.default(&2, String, Openapi.first(Bool.pick(Maybe<&2, String>, _,
    None{}, Some{desc}), Openapi.full(summary)),
    "Executes " ++ String.to_upper(method) ++ " " ++ path) == desc : String}
  {==}

def Laws.oas_describe_summary(summary, method, path, e):
  f = Equal.sym(Bool, String.is_empty(summary), False{}, e)
  %f : {Maybe.default(&2, String, Bool.pick(Maybe<&2, String>, _, None{},
    Some{summary}), "Executes " ++ String.to_upper(method) ++ " " ++ path)
    == summary : String}
  {==}

def Laws.oas_describe_none(_method, _path):
  {==}
