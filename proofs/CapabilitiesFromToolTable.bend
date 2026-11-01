# proofs of laws/CapabilitiesFromToolTable.bend
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/server.bend as Server
import ../laws/CapabilitiesFromToolTable.bend as Laws
import ./lemmas/BoolCharStringFacts.bend as M1
import ./lemmas/InitializeResultShape.bend as M2

def init.lem.caps(
  version: String,
  caps: Value.Json,
  info: Value.Json,
  instructions: String,
  b: Bool
) -> {Json.get(M2.init.of(version, caps, info, instructions, b), "capabilities") == caps : Value.Json}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def Laws.init_caps(name, version, instructions, tools, params):
  init.lem.caps(Server.negotiate(Json.as_str(Json.get(params,
    "protocolVersion"))), Server.capabilities(tools),
    Server.init.info(name, version), instructions,
    String.is_empty(instructions))

def Laws.caps_tools(_t, _rest):
  {==}

def Laws.caps_none(tools, e):
  match tools:
    case []:
      {==}
    case t <> rest:
      M1.absurd(&2, {Server.capabilities(t <> rest) == Json.obj([]) : Value.Json},
        e)
