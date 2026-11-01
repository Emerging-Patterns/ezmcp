# `2025-03-26/basic/lifecycle#version-negotiation`,
# `2025-06-18/basic/lifecycle#version-negotiation` and
# `2025-11-25/basic/lifecycle#version-negotiation`, in the same words: "If
# the server supports the requested protocol version, it **MUST** respond
# with the same version. Otherwise, the server **MUST** respond with another
# protocol version it supports. This **SHOULD** be the _latest_ version
# supported by the server." ezmcp supports exactly 2025-03-26, 2025-06-18
# and 2025-11-25. The result's `protocolVersion` is the requested one when
# ezmcp supports it, and the latest, 2025-11-25, otherwise, including when
# the request names none; for every request it is a version ezmcp supports
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/server.bend as Server

# LAW: the result's protocolVersion is the negotiated one
law init_version:
  for srv: Server.Server
  for params: Value.Json
  {Json.get(Server.init(srv, params), "protocolVersion")
    == Json.str(Server.negotiate(Json.as_str(Json.get(params,
      "protocolVersion")))) : Value.Json}

# LAW: a supported revision is echoed
law negotiate_echo:
  for v: String
  for e: {Server.supported(v) == True{} : Bool}
  {Server.negotiate(Some{v}) == v : String}

# LAW: any other request gets the latest revision
law negotiate_latest:
  for v: String
  for e: {Server.supported(v) == False{} : Bool}
  {Server.negotiate(Some{v}) == "2025-11-25" : String}

# LAW: whatever a client asks for, the answer is a revision ezmcp speaks
law negotiate_supported:
  for asked: Maybe<&2, String>
  {Server.supported(Server.negotiate(asked)) == True{} : Bool}

# LAW: ezmcp supports exactly 2025-03-26, 2025-06-18 and 2025-11-25
law supported_revisions:
  for v: String
  {Server.supported(v) == Bool.or(String.eq(v, "2025-03-26"),
    Bool.or(String.eq(v, "2025-06-18"), String.eq(v, "2025-11-25"))) : Bool}
