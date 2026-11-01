# proofs of laws/StructuredResultsCarryText.bend
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import ../src/server.bend as Server
import ../laws/StructuredResultsCarryText.bend as Laws
import ./lemmas/ArrayItemsRoundTrip.bend as M1

def Laws.structured_value(_v, _bad):
  {==}

def Laws.structured_text(v, _bad):
  M1.eq.items_arr([Server.text(Json.print(v))])
