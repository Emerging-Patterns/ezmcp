# proofs of laws/BatchPostsAnswered.bend
import Base
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/server.bend as Server
import ../src/web.bend as Web
import ../laws/BatchPostsAnswered.bend as Laws

def Laws.web_batch(_rev, _acts):
  {==}

def Laws.web_many_none(replies, e):
  f = Equal.sym(List<&2, Value.Json>, Server.batch.some(replies), [], e)
  %f : {Web.many(Server.batch.gather(_)) == Web.Now{202, [], ""} : Web.Web}
  {==}

def Laws.web_many_some(_batch):
  {==}
