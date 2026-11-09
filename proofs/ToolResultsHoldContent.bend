# proofs of laws/ToolResultsHoldContent.bend
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/rpc.bend as Rpc
import ../src/server.bend as Server
import ../laws/ToolResultsHoldContent.bend as Laws
import ./lemmas/ArrayItemsRoundTrip.bend as M1

def Laws.result_flag(_blocks, _bad):
  {==}

def Laws.result_content(blocks, _bad):
  M1.eq.items_arr(blocks)

def Laws.text_block(_s):
  {==}

def Laws.ran_result(rev, id, result, e):
  f = Equal.sym(Bool, String.eq(rev, "2025-03-26"), False{}, e)
  %f : {Json.get(Rpc.reply(id, Rpc.Ok{Server.shape.of(result, _)}), "result")
    == result : Value.Json}
  {==}
