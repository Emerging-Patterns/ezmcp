# proofs of laws/ClientPostHeaders.bend
import Base
import ezhttp@0.23.0.0/src/http.bend as Http
import ../laws/ClientPostHeaders.bend as Laws

def Laws.headers_first(v, e):
  f = Equal.sym(Bool, String.is_empty(v), True{}, e)
  %f : {Bool.pick(List<&2, Http.Header>, _, [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"}], [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"},
      Http.H{"MCP-Protocol-Version", v}])
    == [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"}] : List<&2, Http.Header>}
  {==}

def Laws.headers_version(v, e):
  f = Equal.sym(Bool, String.is_empty(v), False{}, e)
  %f : {Bool.pick(List<&2, Http.Header>, _, [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"}], [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"},
      Http.H{"MCP-Protocol-Version", v}])
    == [Http.H{"Content-Type", "application/json"},
      Http.H{"Accept", "application/json, text/event-stream"},
      Http.H{"MCP-Protocol-Version", v}] : List<&2, Http.Header>}
  {==}
