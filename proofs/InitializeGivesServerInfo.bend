# proofs of laws/InitializeGivesServerInfo.bend
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/server.bend as Server
import ../laws/InitializeGivesServerInfo.bend as Laws
import ./lemmas/InitializeResultShape.bend as M1

def init.lem.info(
  version: String,
  caps: Value.Json,
  info: Value.Json,
  instructions: String,
  b: Bool
) -> {Json.get(M1.init.of(version, caps, info, instructions, b), "serverInfo") == info : Value.Json}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def Laws.initialize_dispatch(_srv, _params):
  {==}

def Laws.init_info(name, version, instructions, tools, params):
  init.lem.info(Server.negotiate(Json.as_str(Json.get(params,
    "protocolVersion"))), Server.capabilities(tools),
    Server.init.info(name, version), instructions,
    String.is_empty(instructions))

def Laws.init_instructions(name, version, instructions, tools, params, e):
  f = Equal.sym(Bool, String.is_empty(instructions), False{}, e)
  %f : {Json.get(M1.init.of(Server.negotiate(Json.as_str(Json.get(params,
    "protocolVersion"))), Server.capabilities(tools),
    Server.init.info(name, version), instructions, _), "instructions")
    == Json.str(instructions) : Value.Json}
  {==}

def Laws.init_no_instructions(name, version, instructions, tools, params, e):
  f = Equal.sym(Bool, String.is_empty(instructions), True{}, e)
  %f : {Json.has(M1.init.of(Server.negotiate(Json.as_str(Json.get(params,
    "protocolVersion"))), Server.capabilities(tools),
    Server.init.info(name, version), instructions, _), "instructions")
    == False{} : Bool}
  {==}
