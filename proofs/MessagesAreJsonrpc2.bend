# proofs of laws/MessagesAreJsonrpc2.bend
import Base
import ../src/rpc.bend as Rpc
import ../laws/MessagesAreJsonrpc2.bend as Laws

def Laws.reply_v2(_id, out):
  match out:
    case Rpc.Ok{r}:
      {==}
    case Rpc.Err{c, message}:
      {==}

def Laws.request_v2(_id, _m, _params):
  {==}

def Laws.notice_v2(_m, _params):
  {==}

def Laws.not_v2_junk(_has_id, _ok, _id, _m, _params, _r, _e):
  {==}
