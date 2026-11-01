# proofs of laws/RevisionFromVersionHeader.bend
import Base
import ../src/server.bend as Server
import ../src/web.bend as Web
import ../laws/RevisionFromVersionHeader.bend as Laws

def Laws.web_post(srv, header, body, e):
  f = Equal.sym(Bool, Web.version.ok(header), True{}, e)
  %f : {Web.post.ok(srv, body, header, _)
    == Web.act(Web.revision(header),
      Server.step(srv, Web.revision(header), body)) : Web.Web}
  {==}

def Laws.revision_absent(v, e):
  f = Equal.sym(Bool, String.is_empty(v), True{}, e)
  %f : {Bool.pick(String, _, Server.oldest(), v) == "2025-03-26" : String}
  {==}

def Laws.revision_named(v, e):
  f = Equal.sym(Bool, String.is_empty(v), False{}, e)
  %f : {Bool.pick(String, _, Server.oldest(), v) == v : String}
  {==}
