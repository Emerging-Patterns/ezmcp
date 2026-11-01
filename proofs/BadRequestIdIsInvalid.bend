# proofs of laws/BadRequestIdIsInvalid.bend
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import ../src/rpc.bend as Rpc
import ../laws/BadRequestIdIsInvalid.bend as Laws

def Laws.id_other(v, es, en):
  fs = Equal.sym(Maybe<&2, String>, Json.as_str(v), None{}, es)
  fn = Equal.sym(Maybe<&2, String>, Json.as_num(v), None{}, en)
  %fs : {Rpc.id.str(_, v) == False{} : Bool}
  %fn : {Rpc.id.num(_) == False{} : Bool}
  {==}

def Laws.request_bad_id(_id, _m, _params, _r, _e):
  {==}
