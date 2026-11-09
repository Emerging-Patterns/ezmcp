# `basic/lifecycle#version-negotiation`: "If the client does not support the
# version in the server's response, it **SHOULD** disconnect" (the caller's
# to do: `client.ask` leaves checking the revision to its caller).
# `client.version` reads the revision an initialize result names: for every
# string `v`, a result whose `protocolVersion` is `v` names `v`
import Base
import ezjson@1.2.0.0/main.bend as Json
import ../src/client.bend as Client

# LAW: the revision an initialize result names is its protocolVersion
law version_named:
  for v: String
  {Client.version(Json.obj([("protocolVersion", Json.str(v))])) == v
    : String}
