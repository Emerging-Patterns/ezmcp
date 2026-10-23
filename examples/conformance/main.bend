# examples/conformance: the tools the MCP conformance suite's server
# scenarios call (npx @modelcontextprotocol/conformance server), for the ones
# ezmcp has the features for: text, image, audio and embedded resource
# content, several blocks, a tool error, and a JSON Schema 2020-12 input
# schema.
#
#   conformance PORT    POST /mcp on 127.0.0.1:PORT until stopped
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../../main.bend as Mcp
import ../../src/server.bend as Server

# the JSON Schema 2020-12 keywords the json-schema-2020-12 scenario looks
# for in tools/list, passed through as given
def schema2020() -> Value.Json:
  Json.obj([
    ("$schema", Json.str("https://json-schema.org/draft/2020-12/schema")),
    ("type", Json.str("object")),
    ("$defs", Json.obj([("address", Json.obj([("type", Json.str("object")),
      ("properties", Json.obj([
        ("street", Json.obj([("type", Json.str("string"))])),
        ("city", Json.obj([("type", Json.str("string"))]))]))]))])),
    ("properties", Json.obj([
      ("name", Json.obj([("type", Json.str("string"))])),
      ("address", Json.obj([("$ref", Json.str("#/$defs/address"))]))])),
    ("additionalProperties", Json.bool(False{}))])

# a schema for a tool with no arguments
def none() -> Value.Json:
  Json.obj([("type", Json.str("object")), ("properties", Json.obj([]))])

# the scenarios' tools
def srv() -> Server.Server:
  Mcp.server("ezmcp-conformance", "0.1.0", "", [
    Mcp.tool("test_simple_text", "Text content", none()),
    Mcp.tool("test_image_content", "Image content", none()),
    Mcp.tool("test_audio_content", "Audio content", none()),
    Mcp.tool("test_embedded_resource", "Embedded resource content", none()),
    Mcp.tool("test_multiple_content_types", "Several content blocks", none()),
    Mcp.tool("test_error_handling", "A tool error", none()),
    Mcp.tool("json_schema_2020_12_tool", "Tool with JSON Schema 2020-12 features",
      schema2020())])

# a 1x1 red PNG
def png() -> String:
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="

# eight silent samples of 16-bit mono WAV
def wav() -> String:
  "UklGRjQAAABXQVZFZm10IBAAAAABAAEAQB8AAIA+AAACABAAZGF0YRAAAAAAAAAAAAAAAAAAAAAAAAAA"

# a binary content block
def blob(kind: String, data: String, mime: String) -> Value.Json:
  Json.obj([("type", Json.str(kind)), ("data", Json.str(data)),
    ("mimeType", Json.str(mime))])

# an embedded text resource
def resource(uri: String, mime: String, text: String) -> Value.Json:
  Json.obj([("type", Json.str("resource")), ("resource", Json.obj([
    ("uri", Json.str(uri)), ("mimeType", Json.str(mime)),
    ("text", Json.str(text))]))])

# what each tool answers
def answer(+name: String) -> Value.Json:
  Bool.pick(Value.Json, String.eq(name, "test_simple_text"),
    Mcp.result.text("This is a simple text response for testing."),
  Bool.pick(Value.Json, String.eq(name, "test_image_content"),
    Mcp.result([blob("image", png(), "image/png")], False{}),
  Bool.pick(Value.Json, String.eq(name, "test_audio_content"),
    Mcp.result([blob("audio", wav(), "audio/wav")], False{}),
  Bool.pick(Value.Json, String.eq(name, "test_embedded_resource"),
    Mcp.result([resource("test://embedded-resource", "text/plain",
      "This is an embedded resource content.")], False{}),
  Bool.pick(Value.Json, String.eq(name, "test_multiple_content_types"),
    Mcp.result([Mcp.text("Multiple content types test:"),
      blob("image", png(), "image/png"),
      resource("test://mixed-content-resource", "application/json",
        "{\"test\":\"data\",\"value\":123}")], False{}),
    Mcp.result.error("This tool intentionally returns an error for testing"))))))

# run a tool: ezmcp only runs tools the table names
def run(name: String, _args: Value.Json) -> IO(Value.Json):
  IO.pure(Value.Json, answer(name))

# serve on the port the first argument names
@unsafe def serve(args: List<String>) -> IO(Unit):
  match args:
    case _prog <> port <> _rest:
      Mcp.http.serve_forever(~run, ~srv(), ~"/mcp", ~[], "127.0.0.1",
        Maybe.default(&2, U32, U32.read(port), 8000))
    case _other:
      IO.print_err("usage: conformance PORT")

@unsafe def main() -> IO(Unit):
  IO.bind(List<String>, Unit, IO.args(), serve)
