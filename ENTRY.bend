# ezmcp: laws on the entry, main.bend. Its pure names are thin wrappers over
# src/rpc.bend, src/server.bend, src/web.bend and src/client.bend, which
# LAWS.bend states the laws for.
#
# main.bend reaches src/io.bend, which reaches ezhttp's socket effects (user
# foreign code) and the @unsafe serve loops, so from bend 2.0.32 no file
# importing it can print ALL PROOFS CHECK: the verdict covers every def of
# every import. `bend ENTRY.bend` must print SOME PROOFS FAIL with the
# foreign-code list as its only error; the flake's entry check holds it to
# that.
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import 0xa4d47e5f0f6044ac1a983d1b051fa47a/src/http.bend as Http
import ./src/rpc.bend as Rpc
import ./src/server.bend as Server
import ./src/web.bend as Web
import ./src/client.bend as Client
import ./main.bend as Ez

# LAW: tool builds a table entry
law tool_is_tool:
  for name: String
  for description: String
  for input: Value.Json
  {Ez.tool(name, description, input) == Server.Tool{name, description, input}
    : Server.Tool}

# LAW: server builds a server
law server_is_server:
  for name: String
  for version: String
  for instructions: String
  for tools: List<&2, Server.Tool>
  {Ez.server(name, version, instructions, tools)
    == Server.Server{name, version, instructions, tools} : Server.Server}

# LAW: step is src/server.bend's
law step_is_server:
  for srv: Server.Server
  for rev: String
  for text: String
  {Ez.step(srv, rev, text) == Server.step(srv, rev, text) : Server.Act}

# LAW: turn is src/server.bend's
law turn_is_server:
  for srv: Server.Server
  for rev: String
  for text: String
  {Ez.turn(srv, rev, text) == Server.turn(srv, rev, text) : Server.Turn}

# LAW: ran is src/server.bend's
law ran_is_server:
  for rev: String
  for id: Value.Json
  for out: Rpc.Out
  {Ez.ran(rev, id, out) == Server.ran(rev, id, out) : Value.Json}

# LAW: ok is a tool result
law ok_is_result:
  for result: Value.Json
  {Ez.ok(result) == Rpc.Ok{result} : Rpc.Out}

# LAW: refuse is a JSON-RPC error with its code and message
law refuse_is_error:
  for c: Rpc.Code
  for message: String
  {Ez.refuse(c, message) == Rpc.Err{c, message} : Rpc.Out}

# LAW: refuse.params is -32602
law refuse_params_invalid:
  for message: String
  {Ez.refuse.params(message) == Rpc.Err{Rpc.InvalidParams{}, message} : Rpc.Out}

# LAW: refuse.internal is -32603
law refuse_internal_error:
  for message: String
  {Ez.refuse.internal(message) == Rpc.Err{Rpc.InternalError{}, message}
    : Rpc.Out}

# LAW: batch.reply is src/server.bend's
law batch_reply_is_server:
  for replies: List<&2, Maybe<&2, Value.Json>>
  {Ez.batch.reply(replies) == Server.batch.reply(replies)
    : Maybe<&2, Value.Json>}

# LAW: text is a text block
law text_is_server:
  for s: String
  {Ez.text(s) == Server.text(s) : Value.Json}

# LAW: result is src/server.bend's
law result_is_server:
  for blocks: List<&2, Value.Json>
  for bad: Bool
  {Ez.result(blocks, bad) == Server.result(blocks, bad) : Value.Json}

# LAW: result.text is one text block, not an error
law result_text_ok:
  for s: String
  {Ez.result.text(s) == Server.result([Server.text(s)], False{}) : Value.Json}

# LAW: result.error is one text block, an error
law result_error_bad:
  for s: String
  {Ez.result.error(s) == Server.result([Server.text(s)], True{}) : Value.Json}

# LAW: result.json is structured content, not an error
law result_json_ok:
  for v: Value.Json
  {Ez.result.json(v) == Server.structured(v, False{}) : Value.Json}

# LAW: http.decide is src/web.bend's
law http_decide_is_web:
  for srv: Server.Server
  for path: String
  for origins: List<&2, String>
  for req: Http.Request
  {Ez.http.decide(srv, path, origins, req) == Web.decide(srv, path, origins, req)
    : Web.Web}

# LAW: client.initialize is src/client.bend's
law client_initialize_is_client:
  for id: Value.Json
  for name: String
  for version: String
  {Ez.client.initialize(id, name, version) == Client.initialize(id, name, version)
    : Value.Json}

# LAW: client.tools is src/client.bend's
law client_tools_is_client:
  for id: Value.Json
  {Ez.client.tools(id) == Client.tools(id) : Value.Json}

# LAW: client.call is src/client.bend's
law client_call_is_client:
  for id: Value.Json
  for name: String
  for args: Value.Json
  {Ez.client.call(id, name, args) == Client.call(id, name, args) : Value.Json}

# LAW: client.read is src/rpc.bend's
law client_read_is_rpc:
  for text: String
  {Ez.client.read(text) == Rpc.read(text) : Rpc.Reply}

# LAW: client.version is src/client.bend's
law client_version_is_client:
  for result: Value.Json
  {Ez.client.version(result) == Client.version(result) : String}

# --- fills ---

# tool_is_tool holds by unfolding the re-export
def tool_is_tool(_name, _description, _input):
  {==}

# server_is_server holds by unfolding the re-export
def server_is_server(_name, _version, _instructions, _tools):
  {==}

# step_is_server holds by unfolding the re-export
def step_is_server(_srv, _rev, _text):
  {==}

# turn_is_server holds by unfolding the re-export
def turn_is_server(_srv, _rev, _text):
  {==}

# ran_is_server holds by unfolding the re-export
def ran_is_server(_rev, _id, _out):
  {==}

# ok_is_result holds by unfolding the re-export
def ok_is_result(_result):
  {==}

# refuse_is_error holds by unfolding the re-export
def refuse_is_error(_c, _message):
  {==}

# refuse_params_invalid holds by unfolding the re-export
def refuse_params_invalid(_message):
  {==}

# refuse_internal_error holds by unfolding the re-export
def refuse_internal_error(_message):
  {==}

# batch_reply_is_server holds by unfolding the re-export
def batch_reply_is_server(_replies):
  {==}

# text_is_server holds by unfolding the re-export
def text_is_server(_s):
  {==}

# result_is_server holds by unfolding the re-export
def result_is_server(_blocks, _bad):
  {==}

# result_text_ok holds by unfolding the re-export
def result_text_ok(_s):
  {==}

# result_error_bad holds by unfolding the re-export
def result_error_bad(_s):
  {==}

# result_json_ok holds by unfolding the re-export
def result_json_ok(_v):
  {==}

# http_decide_is_web holds by unfolding the re-export
def http_decide_is_web(_srv, _path, _origins, _req):
  {==}

# client_initialize_is_client holds by unfolding the re-export
def client_initialize_is_client(_id, _name, _version):
  {==}

# client_tools_is_client holds by unfolding the re-export
def client_tools_is_client(_id):
  {==}

# client_call_is_client holds by unfolding the re-export
def client_call_is_client(_id, _name, _args):
  {==}

# client_read_is_rpc holds by unfolding the re-export
def client_read_is_rpc(_text):
  {==}

# client_version_is_client holds by unfolding the re-export
def client_version_is_client(_result):
  {==}
