# proofs of laws/RepliesCarryRequestId.bend
import Base
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server
import ../laws/RepliesCarryRequestId.bend as Laws

def Laws.reply_id(_id, out):
  match out:
    case Rpc.Ok{r}:
      {==}
    case Rpc.Err{c, message}:
      {==}

def Laws.answer_id(id, s):
  match s:
    case Server.Now{out}:
      Laws.reply_id(id, out)
    case Server.Call{name, args}:
      {==}

def Laws.ran_id(_rev, _id, out):
  match out:
    case Rpc.Ok{_result}:
      {==}
    case Rpc.Err{_c, _message}:
      {==}
