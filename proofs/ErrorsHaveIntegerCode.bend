# proofs of laws/ErrorsHaveIntegerCode.bend
import Base
import ../src/rpc.bend as Rpc
import ../laws/ErrorsHaveIntegerCode.bend as Laws

def Laws.code_integer(c):
  match c:
    case Rpc.ParseError{}:
      {==}
    case Rpc.InvalidRequest{}:
      {==}
    case Rpc.MethodNotFound{}:
      {==}
    case Rpc.InvalidParams{}:
      {==}
    case Rpc.InternalError{}:
      {==}

def Laws.reply_err_fields(_id, _c, _message):
  {==}
