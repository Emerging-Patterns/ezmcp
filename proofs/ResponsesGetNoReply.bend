# proofs of laws/ResponsesGetNoReply.bend
import Base
import ../src/rpc.bend as Rpc
import ../laws/ResponsesGetNoReply.bend as Laws

def Laws.response_is_answer(id, _params, r, e, one):
  f = Equal.sym(Bool, Rpc.one(r, e), True{}, one)
  %f : {Bool.pick(Rpc.Msg, _, Rpc.Answer{id},
    Rpc.Junk{id, "Invalid Request: no method"}) == Rpc.Answer{id} : Rpc.Msg}
  {==}

def Laws.answer_is_quiet(_srv, _id):
  {==}
