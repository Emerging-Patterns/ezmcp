# proofs of laws/BlankLinesGetNothing.bend
import Base
import ../src/server.bend as Server
import ../src/line.bend as Line
import ../laws/BlankLinesGetNothing.bend as Laws

def Laws.line_blank(srv, rev, text, e):
  f = Equal.sym(Bool, String.is_empty(String.trim(text)), True{}, e)
  %f : {Line.line.of(srv, rev, text, _) == Server.Turn{Server.Quiet{}, rev}
    : Server.Turn}
  {==}

def Laws.line_message(srv, rev, text, e):
  f = Equal.sym(Bool, String.is_empty(String.trim(text)), False{}, e)
  %f : {Line.line.of(srv, rev, text, _) == Server.turn(srv, rev, text)
    : Server.Turn}
  {==}
