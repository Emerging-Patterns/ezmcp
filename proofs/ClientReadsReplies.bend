# proofs of laws/ClientReadsReplies.bend
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../laws/ClientReadsReplies.bend as Laws

def Laws.took_status_200(_status, _ctype, _text):
  {==}

def Laws.read_got(_id, _result, _c, _m):
  {==}

def Laws.read_refused(_id, _result, _c, _m):
  {==}

def Laws.read_both(_id, _result, b, _c, _m):
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def Laws.read_not_v2(_id, _r, _result, _e, _c, _m):
  {==}

def Laws.read_not_json(text, e):
  f = Equal.sym(Maybe<&2, Value.Json>, Json.parse(text), None{}, e)
  %f : {Rpc.read.parsed(_) == Rpc.Unread{"the reply is not JSON"} : Rpc.Reply}
  {==}

def Laws.took_status(_ctype, _text, _status):
  {==}
