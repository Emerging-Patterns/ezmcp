# proofs of laws/OperationsFromPaths.bend
import Base
import ezjson@1.2.0.0/main.bend as Json
import ../src/openapi.bend as Openapi
import ../laws/OperationsFromPaths.bend as Laws

def Laws.oas_ops(_doc):
  {==}

def Laws.oas_paths(_path, _it, _rest, _doc):
  {==}

def Laws.oas_methods(_doc, _path, _it, _ips):
  {==}

def Laws.oas_item_take(method, ms, doc, path, it, ips, e):
  f = Equal.sym(Bool, Json.is_obj(Json.get(it, method)), True{}, e)
  %f : {Openapi.item.at(_, doc, path, method, ips, Json.get(it, method),
    Openapi.item(ms, doc, path, it, ips))
    == Openapi.op(doc, path, method, ips, Json.get(it, method))
      <> Openapi.item(ms, doc, path, it, ips) : List<&2, Openapi.Op>}
  {==}

def Laws.oas_item_skip(method, ms, doc, path, it, ips, e):
  f = Equal.sym(Bool, Json.is_obj(Json.get(it, method)), False{}, e)
  %f : {Openapi.item.at(_, doc, path, method, ips, Json.get(it, method),
    Openapi.item(ms, doc, path, it, ips))
    == Openapi.item(ms, doc, path, it, ips) : List<&2, Openapi.Op>}
  {==}

# members read back from the cells they make are those members
def oas.members_cells(
  ps: List<&2, Openapi.Mem()>
) -> {Openapi.members.go(Openapi.cells(ps)) == ps : List<&2, Openapi.Mem()>}:
  match ps:
    case []:
      {==}
    case (key, val) <> rest:
      Equal.cong(List<&2, Openapi.Mem()>, List<&2, Openapi.Mem()>,
        r => (key, val) <> r, Openapi.members.go(Openapi.cells(rest)), rest,
        oas.members_cells(rest))

def Laws.oas_members(ps):
  oas.members_cells(ps)
