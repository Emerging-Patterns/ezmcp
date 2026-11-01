# `src/openapi.bend` reads an OpenAPI 3.0 or 3.1 document, a JSON value the
# caller has already read, as a tool table (`Openapi.ops`, one `Op` for each
# operation, and `Openapi.tool` of each), and a tool call as the HTTP
# request it stands for (`Openapi.check`, then `Openapi.call`). It does no
# IO: reading the document and sending the request are the caller's, as are
# the server's base URL and any credential (a document's `servers` and
# security schemes are not read). `server/tools#tool`: a tool has a `name`,
# a `description` and an `inputSchema`, "JSON Schema defining expected
# parameters"; an operation's tool takes its parameters by name and its
# request body as the argument `requestBody`.
#
# The OpenAPI guarantees cite the OpenAPI Specification by its anchors under
# <https://spec.openapis.org/>: `oas/v3.1.0#parameter-object` is 3.1.0's
# Parameter Object, whose words 3.0.3 (`oas/v3.0.3#...`) shares unless the
# guarantee cites its own, and `RFC 6901 §N` is a section of JSON Pointer.
# Where neither specification decides (what to call a tool, which media type
# a body is sent as, how a schema becomes an input schema), ezmcp makes
# openapi-mcp-generator's choice (v4,
# <https://github.com/harsha-iiiv/openapi-mcp-generator>), so a server built
# by it and rebuilt on ezmcp keeps its tool table; each such choice is named
# in its guarantee.
#
# `oas/v3.1.0#paths-object`: the Paths Object "Holds the relative paths to
# the individual endpoints and their operations"; `#path-item-object`: a
# Path Item "Describes the operations available on a single path", one
# member for each of `get`, `put`, `post`, `delete`, `options`, `head`,
# `patch` and `trace`. A document's operations are, for each member of its
# `paths` in order, that Path Item's operations: one for each of those eight
# methods, in that order, whose member is an object, and none for any other
# member (a missing method, `summary`, `servers`, `parameters`, an
# extension). An object's members are read in order, and the object they
# make reads back as the same members
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/openapi.bend as Openapi

# LAW: a document's operations are those of its paths' Path Items, in order
law oas_ops:
  for +doc: Value.Json
  {Openapi.ops(doc) == Openapi.paths(Openapi.members(Json.get(doc, "paths")),
    doc) : List<&2, Openapi.Op>}

# LAW: a path's operations come first, then the other paths', each path's
# for the methods in order, after its parameters with references followed
law oas_paths:
  for +path: String
  for +it: Value.Json
  for rest: List<&2, Openapi.Mem()>
  for +doc: Value.Json
  {Openapi.paths((path, it) <> rest, doc)
    == List.append(&2, Openapi.Op, Openapi.item(Openapi.methods(), doc, path,
      it, Json.items(Openapi.dereferenced(doc, Json.get(it, "parameters")))),
      Openapi.paths(rest, doc)) : List<&2, Openapi.Op>}

# LAW: the methods are get, put, post, delete, options, head, patch and
# trace, in that order
law oas_methods:
  for +doc: Value.Json
  for +path: String
  for +it: Value.Json
  for +ips: List<&2, Value.Json>
  {Openapi.item(Openapi.methods(), doc, path, it, ips)
    == Openapi.item(["get", "put", "post", "delete", "options", "head",
      "patch", "trace"], doc, path, it, ips) : List<&2, Openapi.Op>}

# LAW: a method whose member is an object is an operation, before the rest
law oas_item_take:
  for +method: String
  for ms: List<&2, String>
  for +doc: Value.Json
  for +path: String
  for +it: Value.Json
  for +ips: List<&2, Value.Json>
  for e: {Json.is_obj(Json.get(it, method)) == True{} : Bool}
  {Openapi.item(method <> ms, doc, path, it, ips)
    == Openapi.op(doc, path, method, ips, Json.get(it, method))
      <> Openapi.item(ms, doc, path, it, ips) : List<&2, Openapi.Op>}

# LAW: any other method is no operation
law oas_item_skip:
  for +method: String
  for ms: List<&2, String>
  for +doc: Value.Json
  for +path: String
  for +it: Value.Json
  for +ips: List<&2, Value.Json>
  for e: {Json.is_obj(Json.get(it, method)) == False{} : Bool}
  {Openapi.item(method <> ms, doc, path, it, ips)
    == Openapi.item(ms, doc, path, it, ips) : List<&2, Openapi.Op>}

# LAW: an object's members are the members it was made of, in order
law oas_members:
  for ps: List<&2, Openapi.Mem()>
  {Openapi.members(Openapi.object(ps)) == ps : List<&2, Openapi.Mem()>}
