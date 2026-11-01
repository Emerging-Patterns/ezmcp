# proofs of laws/RequestsCarryValidId.bend
import Base
import ../src/rpc.bend as Rpc
import ../laws/RequestsCarryValidId.bend as Laws

def Laws.request_is_ask(_id, _m, _params, _r, _e):
  {==}

def Laws.id_string(_s):
  {==}

def Laws.id_number(_raw):
  {==}

def Laws.int_minus(_t):
  {==}

def Laws.int_digits(h, t, e):
  f = Equal.sym(Bool, Char.is_eq(h, '-'), False{}, e)
  %f : {Rpc.int.text.of(h, t, _) == Rpc.digits(SCon{h, t}) : Bool}
  {==}
