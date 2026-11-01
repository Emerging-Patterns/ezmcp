# `basic/lifecycle#version-negotiation`: "If the client does not support the
# version in the server's response, it **SHOULD** disconnect" (the caller's
# to do: `client.ask` leaves checking the revision to its caller).
# `client.version` reads the revision an initialize result names: for every
# string `v`, a result whose `protocolVersion` is `v` names `v`
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import ../src/client.bend as Client

# LAW: the revision an initialize result names is its protocolVersion
law version_named:
  for v: String
  {Client.version(Json.obj([("protocolVersion", Json.str(v))])) == v
    : String}
