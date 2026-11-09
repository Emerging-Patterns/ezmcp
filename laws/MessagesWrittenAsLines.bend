# `basic/transports#stdio`: messages "**MUST NOT** contain embedded
# newlines." A message written to stdout is its compact JSON text and one
# newline. That the JSON text holds no newline rests on ezjson's printer,
# pinned in ez.lock.toml: it escapes every control character in a string
# (ezjson's laws/QuoteEscapesExactly.bend) and writes no whitespace outside
# strings, which ezjson proves for the print of a parsed value (ezjson's
# laws/PrintIsCompactAndStable.bend) but not for every value built with it,
# as ezmcp's messages are; for those it is trusted, not proved.
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/line.bend as Line

# LAW: a message on stdout is its JSON text and one newline
law frame_line:
  for v: Value.Json
  {Line.frame(v) == Json.print(v) ++ "\n" : String}
