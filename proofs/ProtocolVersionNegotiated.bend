# proofs of laws/ProtocolVersionNegotiated.bend
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/server.bend as Server
import ../laws/ProtocolVersionNegotiated.bend as Laws
import ./lemmas/InitializeResultShape.bend as M1

# --- version negotiation ---

# the answer for a revision whose support is b is a supported one
def negotiate.lem(
  v: String,
  b: Bool,
  e: {Server.supported(v) == b : Bool}
) -> {Server.supported(Server.negotiate.of(v, b)) == True{} : Bool}:
  match b:
    case True{}:
      e
    case False{}:
      {==}

def init.lem.version(
  version: String,
  caps: Value.Json,
  info: Value.Json,
  instructions: String,
  b: Bool
) -> {Json.get(M1.init.of(version, caps, info, instructions, b), "protocolVersion") == Json.str(version) : Value.Json}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def Laws.init_version(srv, params):
  match srv:
    case Server.Server{name, version, +instructions, tools}:
      init.lem.version(Server.negotiate(Json.as_str(Json.get(params,
        "protocolVersion"))), Server.capabilities(tools),
        Server.init.info(name, version), instructions,
        String.is_empty(instructions))

def Laws.negotiate_echo(v, e):
  f = Equal.sym(Bool, Server.supported(v), True{}, e)
  %f : {Server.negotiate.of(v, _) == v : String}
  {==}

def Laws.negotiate_latest(v, e):
  f = Equal.sym(Bool, Server.supported(v), False{}, e)
  %f : {Server.negotiate.of(v, _) == "2025-11-25" : String}
  {==}

def Laws.negotiate_supported(asked):
  match asked:
    case None{}:
      {==}
    case Some{+v}:
      negotiate.lem(v, Server.supported(v), {==})

# --- revisions, batches and streams ---

def Laws.supported_revisions(_v):
  {==}
