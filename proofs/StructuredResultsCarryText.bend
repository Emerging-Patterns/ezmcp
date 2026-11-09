# proofs of laws/StructuredResultsCarryText.bend
import Base
import ezjson@1.2.0.0/main.bend as Json
import ../src/server.bend as Server
import ../laws/StructuredResultsCarryText.bend as Laws
import ./lemmas/ArrayItemsRoundTrip.bend as M1

def Laws.structured_value(_v, _bad):
  {==}

def Laws.structured_text(v, _bad):
  M1.eq.items_arr([Server.text(Json.print(v))])
