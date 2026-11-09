# `basic/lifecycle#initialization`: "The client **MUST** initiate this phase
# by sending an `initialize` request containing: Protocol version supported,
# Client capabilities, Client implementation information";
# `#version-negotiation`: it "**SHOULD** be the _latest_ version supported
# by the client." `client.initialize`'s params are exactly `protocolVersion`
# 2025-11-25, the latest revision ezmcp speaks, `capabilities` `{}` and
# `clientInfo` with the client's name and version
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/server.bend as Server
import ../src/client.bend as Client

# LAW: initialize sends the latest revision, capabilities and clientInfo
law initialize_params:
  for id: Value.Json
  for name: String
  for version: String
  {Json.get(Client.initialize(id, name, version), "params")
    == Json.obj([("protocolVersion", Json.str(Server.latest())),
      ("capabilities", Json.obj([])),
      ("clientInfo", Json.obj([("name", Json.str(name)),
        ("version", Json.str(version))]))]) : Value.Json}
