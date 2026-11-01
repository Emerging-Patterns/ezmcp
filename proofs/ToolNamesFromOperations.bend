# proofs of laws/ToolNamesFromOperations.bend
import Base
import ../src/openapi.bend as Openapi
import ../laws/ToolNamesFromOperations.bend as Laws

def Laws.oas_name_id(id, method, path, e):
  f = Equal.sym(Bool, String.is_empty(id), False{}, e)
  %f : {Openapi.sanitize(Maybe.default(&2, String, Bool.pick(Maybe<&2, String>,
    _, None{}, Some{id}), Openapi.generated(method, path)))
    == Openapi.sanitize(id) : String}
  {==}

def Laws.oas_name_none(_method, _path):
  {==}

def Laws.oas_sanitize_keep(cp, rest, e):
  f = Equal.sym(Bool, Openapi.name.ok(cp), True{}, e)
  %f : {SCon{Openapi.name.char(_, cp), Openapi.sanitize(rest)}
    == SCon{Chr{cp}, Openapi.sanitize(rest)} : String}
  {==}

def Laws.oas_sanitize_swap(cp, rest, e):
  f = Equal.sym(Bool, Openapi.name.ok(cp), False{}, e)
  %f : {SCon{Openapi.name.char(_, cp), Openapi.sanitize(rest)}
    == SCon{'_', Openapi.sanitize(rest)} : String}
  {==}

# a sanitized string is as long as the string
def oas.sanitize_len(
  text: String
) -> {String.length(Openapi.sanitize(text)) == String.length(text) : Nat}:
  match text:
    case SNil{}:
      {==}
    case SCon{Chr{cp}, rest}:
      Equal.cong(Nat, Nat, n => 1n+n, String.length(Openapi.sanitize(rest)),
        String.length(rest), oas.sanitize_len(rest))

def Laws.oas_sanitize_length(text):
  oas.sanitize_len(text)

def Laws.oas_tool(_name, _description, _input, _method, _path, _params, _media):
  {==}

def Laws.oas_name(_name, _description, _input, _method, _path, _params, _media):
  {==}

def Laws.oas_renamed(_name, _description, _input, _method, _path, _params, _media, _to):
  {==}
