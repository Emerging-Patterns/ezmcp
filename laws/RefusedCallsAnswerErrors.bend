# `server/tools#error-handling` (2025-03-26 and 2025-06-18): "Protocol
# Errors: Standard JSON-RPC errors for issues like: Unknown tools; Invalid
# arguments; Server errors" and "Tool Execution Errors: Reported in tool
# results with `isError: true`"; `2025-11-25/server/tools#error-handling`:
# protocol errors for "Malformed requests (requests that fail to satisfy
# CallToolRequest schema)" and "Server errors", input validation errors as
# tool execution errors, which "contain actionable feedback that language
# models can use to self-correct". A runner answers either a tool result
# (`ok`), whose `isError` reports an execution failure
# (laws/ToolResultsHoldContent.bend), or a protocol error (`refuse`,
# `refuse.params`, `refuse.internal`) of a JSON-RPC §5.1 code and a message.
# Under every revision the reply to a refused call is exactly the error
# response with the call's id, that code and that message, and no result
# (laws/RepliesCarryRequestId.bend, laws/RepliesHaveResultOrError.bend,
# laws/ErrorsHaveIntegerCode.bend). Which of the two a failure is, is the
# runner's choice (trusted in main.bend)
#
# also rests on: laws/RepliesCarryRequestId.bend
import Base
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server

# LAW: a runner that refuses a call is answered with its error, under any
# revision
law ran_refused:
  for rev: String
  for id: Value.Json
  for c: Rpc.Code
  for message: String
  {Server.ran(rev, id, Rpc.Err{c, message}) == Rpc.reply(id, Rpc.Err{c, message})
    : Value.Json}
