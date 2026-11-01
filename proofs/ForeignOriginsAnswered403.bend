# proofs of laws/ForeignOriginsAnswered403.bend
import Base
import ../src/rpc.bend as Rpc
import ../src/web.bend as Web
import ../laws/ForeignOriginsAnswered403.bend as Laws
import ./lemmas/CompareSelfEqual.bend as M1

# an origin check whose second test held holds, whatever the first
def eq.origin_or_true(
  hit: Bool
) -> {Web.origin.or(hit, _u => Web.origin.or(True{}, _v => False{}))
  == True{} : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      {==}

# a hit whose misses are false is the hit
def eq.origin_or_or(
  hit: Bool
) -> {Web.origin.or(Web.origin.or(hit, _u => False{}), _v => False{})
  == hit : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      {==}

def Laws.web_origin(_srv, _is_post, _header, _body):
  {==}

def Laws.origin_absent(_origins):
  {==}

def Laws.origin_loopback(origins, origin, e):
  f = Equal.sym(Bool, Web.loopback(origin), True{}, e)
  %f : {Web.origin.or(String.is_empty(origin), _u => Web.origin.or(_,
    _v => Web.origin.listed(origins, origin))) == True{} : Bool}
  eq.origin_or_true(String.is_empty(origin))

def Laws.loopback_localhost(port):
  eq.origin_or_or(Rpc.digits(port))

def Laws.loopback_ipv4(port):
  eq.origin_or_or(Rpc.digits(port))

def Laws.origin_other(origins, origin, ee, el):
  fe = Equal.sym(Bool, String.is_empty(origin), False{}, ee)
  fl = Equal.sym(Bool, Web.loopback(origin), False{}, el)
  %fe : {Web.origin.or(_, _u => Web.origin.or(Web.loopback(origin),
    _v => Web.origin.listed(origins, origin)))
    == Web.origin.listed(origins, origin) : Bool}
  %fl : {Web.origin.or(_, _v => Web.origin.listed(origins, origin))
    == Web.origin.listed(origins, origin) : Bool}
  {==}

def Laws.origin_listed(origin, rest):
  f = Equal.sym(Bool, String.eq(origin, origin), True{}, M1.eq.string_self(origin))
  %f : {Web.origin.or(_, _u => Web.origin.listed(rest, origin)) == True{}
    : Bool}
  {==}

def Laws.origin_none(_origin):
  {==}

def Laws.origin_unlisted(listed, rest, origin, e):
  f = Equal.sym(Bool, String.eq(listed, origin), False{}, e)
  %f : {Web.origin.or(_, _u => Web.origin.listed(rest, origin))
    == Web.origin.listed(rest, origin) : Bool}
  {==}
