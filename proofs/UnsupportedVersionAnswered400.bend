# proofs of laws/UnsupportedVersionAnswered400.bend
import Base
import ../src/web.bend as Web
import ../laws/UnsupportedVersionAnswered400.bend as Laws

def Laws.web_version(srv, header, body, e):
  f = Equal.sym(Bool, Web.version.ok(header), False{}, e)
  %f : {Web.post.ok(srv, body, header, _)
    == Web.text(400, "Bad Request: unsupported MCP-Protocol-Version")
    : Web.Web}
  {==}

def Laws.version_ok(_v):
  {==}
