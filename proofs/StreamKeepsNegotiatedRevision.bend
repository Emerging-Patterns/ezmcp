# proofs of laws/StreamKeepsNegotiatedRevision.bend
import Base
import ../src/server.bend as Server
import ../laws/StreamKeepsNegotiatedRevision.bend as Laws

def Laws.session_init(_rev, _id, _params):
  {==}

def Laws.session_ask(rev, _id, m, params, e):
  f = Equal.sym(Bool, String.eq(m, "initialize"), False{}, e)
  %f : {Server.session.ask(rev, params, _) == rev : String}
  {==}

def Laws.session_tell(_rev, _m, _params):
  {==}

def Laws.session_answer(_rev, _id):
  {==}

def Laws.session_junk(_rev, _id, _why):
  {==}

def Laws.turn_one(_srv, _rev, _v):
  {==}

def Laws.turn_unparsed(_srv, _rev):
  {==}

def Laws.step_turn(_srv, _rev, _text):
  {==}
