# `basic/transports#protocol-version-header` (2025-06-18 and 2025-11-25):
# the server assumes 2025-03-26 only when it "has no other way to identify
# the version - for example, by relying on the protocol version negotiated
# during initialization"; `2025-03-26/basic/lifecycle#version-negotiation`:
# "If the server supports the requested protocol version, it **MUST**
# respond with the same version." On a stream, the revision the next message
# is read by is the one the server answered an `initialize` request with,
# and is unchanged by any other request, a notification, a response, an
# invalid request, text that is not JSON, a blank line or a batch; a message
# that is not a batch is acted on as one message. `step` is the act of that
# turn. The stdio transport starts at the latest revision (trusted in
# src/io.bend)
#
# also rests on: laws/BlankLinesGetNothing.bend
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server

# LAW: after an initialize, a stream is read by the revision answered to it
law session_init:
  for rev: String
  for id: Value.Json
  for params: Value.Json
  {Server.session(rev, Rpc.Ask{id, "initialize", params})
    == Server.negotiate(Json.as_str(Json.get(params, "protocolVersion")))
    : String}

# LAW: any other request leaves the revision as it was
law session_ask:
  for rev: String
  for id: Value.Json
  for +m: String
  for params: Value.Json
  for e: {String.eq(m, "initialize") == False{} : Bool}
  {Server.session(rev, Rpc.Ask{id, m, params}) == rev : String}

# LAW: so does a notification
law session_tell:
  for rev: String
  for m: String
  for params: Value.Json
  {Server.session(rev, Rpc.Tell{m, params}) == rev : String}

# LAW: and a response
law session_answer:
  for rev: String
  for id: Value.Json
  {Server.session(rev, Rpc.Answer{id}) == rev : String}

# LAW: and an invalid request
law session_junk:
  for rev: String
  for id: Value.Json
  for why: String
  {Server.session(rev, Rpc.Junk{id, why}) == rev : String}

# LAW: a message that is not a batch is acted on, and moves the revision, as
# one message
law turn_one:
  for srv: Server.Server
  for rev: String
  for v: Value.Json
  {Server.turn.value(srv, rev, v, False{})
    == Server.Turn{Server.handle(srv, Rpc.classify(v)),
      Server.session(rev, Rpc.classify(v))} : Server.Turn}

# LAW: text that is not JSON leaves the revision as it was
law turn_unparsed:
  for srv: Server.Server
  for rev: String
  {Server.turn.parsed(srv, rev, None{})
    == Server.Turn{Server.unparsed(), rev} : Server.Turn}

# LAW: step is a turn's act
law step_turn:
  for srv: Server.Server
  for rev: String
  for text: String
  {Server.step(srv, rev, text) == Server.turn.act(Server.turn(srv, rev, text))
    : Server.Act}
