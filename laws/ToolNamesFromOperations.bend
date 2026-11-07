# `oas/v3.1.0#operation-object`: operationId is a "Unique string used to
# identify the operation ... Tools and libraries MAY use the operationId to
# uniquely identify an operation"; `2025-11-25/server/tools#tool-names`:
# names "SHOULD" use only "uppercase and lowercase ASCII letters (A-Z, a-z),
# digits (0-9), underscore (_), hyphen (-), and dot (.)". An operation's
# tool name is its `operationId` when that is a non-empty string, else a
# name made from its method and path (openapi-mcp-generator's
# `generateOperationId`), with each character other than an ASCII letter, a
# digit, `_` and `-` written as `_`, one for one, so the name keeps its
# length (`.` too, as openapi-mcp-generator writes it). `tool` is exactly
# the operation's name, description and input schema, `name` its name, and
# `renamed` changes the name and nothing else
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/server.bend as Server
import ../src/openapi.bend as Openapi

# LAW: a non-empty operationId is the name, sanitized
law oas_name_id:
  for +id: String
  for method: String
  for path: String
  for e: {String.is_empty(id) == False{} : Bool}
  {Openapi.name.of(Some{id}, method, path) == Openapi.sanitize(id) : String}

# LAW: with no operationId the name is made from the method and path
law oas_name_none:
  for +method: String
  for +path: String
  {Openapi.name.of(None{}, method, path)
    == Openapi.sanitize(Openapi.generated(method, path)) : String}

# LAW: a character that may stand in a tool name is kept
law oas_sanitize_keep:
  for +cp: U32
  for rest: String
  for e: {Openapi.name.ok(cp) == True{} : Bool}
  {Openapi.sanitize(SCon{Chr{cp}, rest}) == SCon{Chr{cp}, Openapi.sanitize(rest)}
    : String}

# LAW: any other is written as `_`
law oas_sanitize_swap:
  for +cp: U32
  for rest: String
  for e: {Openapi.name.ok(cp) == False{} : Bool}
  {Openapi.sanitize(SCon{Chr{cp}, rest}) == SCon{'_', Openapi.sanitize(rest)}
    : String}

# LAW: a sanitized name has the length it had
law oas_sanitize_length:
  for +text: String
  {String.length(Openapi.sanitize(text)) == String.length(text) : Nat}

# LAW: an operation's tool is its name, description and input schema
law oas_tool:
  for name: String
  for description: String
  for input: Value.Json
  for method: String
  for path: String
  for params: List<&2, Openapi.Param>
  for media: String
  {Openapi.tool(Openapi.Op{name, description, input, method, path, params,
    media}) == Server.ToolSpec{name, description, input} : Server.ToolSpec}

# LAW: an operation's name is its tool's
law oas_name:
  for name: String
  for description: String
  for input: Value.Json
  for method: String
  for path: String
  for params: List<&2, Openapi.Param>
  for media: String
  {Openapi.name(Openapi.Op{name, description, input, method, path, params,
    media}) == name : String}

# LAW: a renamed operation has the new name and all else it had
law oas_renamed:
  for name: String
  for description: String
  for input: Value.Json
  for method: String
  for path: String
  for params: List<&2, Openapi.Param>
  for media: String
  for to: String
  {Openapi.renamed(Openapi.Op{name, description, input, method, path, params,
    media}, to) == Openapi.Op{to, description, input, method, path, params,
    media} : Openapi.Op}
