# ezmcp/src/rpc: JSON-RPC 2.0 as MCP 2025-06-18 uses it, with no IO. One
# decoded message is classified as a request, a notification, a response or
# an invalid request; replies and requests are built here; a reply a client
# reads back is classified here too.
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value

# what one incoming message is (JSON-RPC 2.0 §4, MCP basic#messages)
type Msg is Data:
  Ask{id: Value.Json, method: String, params: Value.Json}
  Tell{method: String, params: Value.Json}
  Answer{id: Value.Json}
  Junk{id: Value.Json, why: String}

# the fields of a message the classification looks at
type Head is Data:
  Head{obj: Bool, v2: Bool, has_id: Bool, id_ok: Bool, id: Value.Json,
    method: Maybe<&2, String>, params: Value.Json, has_result: Bool,
    has_error: Bool}

# the error codes JSON-RPC 2.0 §5.1 predefines
type Code is Data:
  ParseError{}
  InvalidRequest{}
  MethodNotFound{}
  InvalidParams{}
  InternalError{}

# how a request ends: a result, or an error with its code and message
type Out is Data:
  Ok{result: Value.Json}
  Err{code: Code, message: String}

# what a reply a client reads says
type Reply is Data:
  Got{id: Value.Json, result: Value.Json}
  Refused{id: Value.Json, code: String, message: String}
  Unread{why: String}

# --- integers and ids ---

# the rest of a test that holds so far: false once one char fails
def digits.and(ok: Bool, rest: Unit -> Bool) -> Bool:
  match ok:
    case True{}:
      rest(Unit{})
    case False{}:
      False{}

# whether every char of a text is an ASCII digit (true for the empty text)
def digits.go(text: String) -> Bool:
  match text:
    case SNil{}:
      True{}
    case SCon{head, tail}:
      digits.and(Char.is_digit(head), _u => digits.go(tail))

# whether a text is one or more ASCII digits
def digits(text: String) -> Bool:
  match text:
    case SNil{}:
      False{}
    case SCon{head, tail}:
      digits.and(Char.is_digit(head), _u => digits.go(tail))

# an integer's text after its first char: digits after a minus, else the
# first char a digit and digits after it
def int.text.of(head: Char, tail: String, minus: Bool) -> Bool:
  match minus:
    case True{}:
      digits(tail)
    case False{}:
      digits(SCon{head, tail})

# whether a number's text is an integer: an optional minus, then digits
def int.text(text: String) -> Bool:
  match text:
    case SNil{}:
      False{}
    case SCon{+head, tail}:
      int.text.of(head, tail, Char.is_eq(head, '-'))

def id.num(meth: Maybe<&2, String>) -> Bool:
  match meth:
    case None{}:
      False{}
    case Some{raw}:
      int.text(raw)

def id.str(meth: Maybe<&2, String>, +val: Value.Json) -> Bool:
  match meth:
    case Some{_s}:
      True{}
    case None{}:
      id.num(Json.as_num(val))

# whether a value is a request id MCP allows: a string or an integer, never
# null (basic#requests)
def id.ok(+val: Value.Json) -> Bool:
  id.str(Json.as_str(val), val)

# --- classification ---

def is.v2(meth: Maybe<&2, String>) -> Bool:
  match meth:
    case None{}:
      False{}
    case Some{s}:
      String.eq(s, "2.0")

# the fields of one decoded message
def head(+val: Value.Json) -> Head:
  Head{Json.is_obj(val), is.v2(Json.as_str(Json.get(val, "jsonrpc"))),
    Json.has(val, "id"), id.ok(Json.get(val, "id")), Json.get(val, "id"),
    Json.as_str(Json.get(val, "method")), Json.get(val, "params"),
    Json.has(val, "result"), Json.has(val, "error")}

# the id an error reply to a message carries: its own when it has a valid
# one, null otherwise (JSON-RPC 2.0 §5)
def head.id(has_id: Bool, id_ok: Bool, id: Value.Json) -> Value.Json:
  Bool.pick(Value.Json, Bool.and(has_id, id_ok), id, Json.null())

# a message with a method: a request when it has an id, which must be a
# valid one; a notification when it has none
def decide.method(
  has_id: Bool,
  id_ok: Bool,
  id: Value.Json,
  method: String,
  params: Value.Json
) -> Msg:
  match has_id:
    case False{}:
      Tell{method, params}
    case True{}:
      Bool.pick(Msg, id_ok, Ask{id, method, params},
        Junk{Json.null(), "Invalid Request: id must be a string or an integer"})

# whether exactly one of two is true
def one(lead: Bool, byte: Bool) -> Bool:
  match lead byte:
    case True{} False{}:
      True{}
    case False{} True{}:
      True{}
    case x y:
      False{}

# a message with no method: a response when it has a valid id and exactly
# one of result and error
def decide.answer(
  +has_id: Bool,
  +id_ok: Bool,
  +id: Value.Json,
  has_result: Bool,
  has_error: Bool
) -> Msg:
  Bool.pick(Msg, Bool.and(Bool.and(has_id, id_ok),
      one(has_result, has_error)),
    Answer{id}, Junk{head.id(has_id, id_ok, id), "Invalid Request: no method"})

def decide.kind(
  has_id: Bool,
  +id_ok: Bool,
  +id: Value.Json,
  method: Maybe<&2, String>,
  params: Value.Json,
  has_result: Bool,
  has_error: Bool
) -> Msg:
  match method:
    case Some{m}:
      decide.method(has_id, id_ok, id, m, params)
    case None{}:
      decide.answer(has_id, id_ok, id, has_result, has_error)

def decide.v2(
  v2: Bool,
  +has_id: Bool,
  +id_ok: Bool,
  +id: Value.Json,
  method: Maybe<&2, String>,
  params: Value.Json,
  has_result: Bool,
  has_error: Bool
) -> Msg:
  match v2:
    case False{}:
      Junk{head.id(has_id, id_ok, id),
        "Invalid Request: jsonrpc must be \"2.0\""}
    case True{}:
      decide.kind(has_id, id_ok, id, method, params, has_result, has_error)

# what a message is, from its fields
def decide(head: Head) -> Msg:
  match head:
    case Head{obj, v2, has_id, id_ok, id, method, params, has_result, has_error}:
      Bool.pick(Msg, obj,
        decide.v2(v2, has_id, id_ok, id, method, params, has_result,
          has_error),
        Junk{Json.null(), "Invalid Request: not a JSON-RPC object"})

# what one decoded message is
def classify(val: Value.Json) -> Msg:
  decide(head(val))

# --- replies ---

# an error code's number
def code.num(cb: Code) -> String:
  match cb:
    case ParseError{}:
      "-32700"
    case InvalidRequest{}:
      "-32600"
    case MethodNotFound{}:
      "-32601"
    case InvalidParams{}:
      "-32602"
    case InternalError{}:
      "-32603"

# an error object: an integer code and a message (basic#responses)
def error.obj(cb: Code, message: String) -> Value.Json:
  Json.obj([("code", Json.num(code.num(cb))), ("message", Json.str(message))])

# the reply to a request with this id (MCP basic#responses)
def reply(id: Value.Json, out: Out) -> Value.Json:
  match out:
    case Ok{result}:
      Json.obj([("jsonrpc", Json.str("2.0")), ("id", id), ("result", result)])
    case Err{c, message}:
      Json.obj([("jsonrpc", Json.str("2.0")), ("id", id),
        ("error", error.obj(c, message))])

# a request: jsonrpc, id, method and params
def request(id: Value.Json, method: String, params: Value.Json) -> Value.Json:
  Json.obj([("jsonrpc", Json.str("2.0")), ("id", id),
    ("method", Json.str(method)), ("params", params)])

# a notification: jsonrpc, method and params, and no id
def notice(method: String, params: Value.Json) -> Value.Json:
  Json.obj([("jsonrpc", Json.str("2.0")), ("method", Json.str(method)),
    ("params", params)])

# --- reading a reply (client side) ---

# the fields of a reply a client reads
type Back is Data:
  Back{v2: Bool, id: Value.Json, has_result: Bool, result: Value.Json,
    has_error: Bool, code: Maybe<&2, String>, message: Maybe<&2, String>}

def back.refused(
  id: Value.Json,
  code: Maybe<&2, String>,
  message: Maybe<&2, String>
) -> Reply:
  match code message:
    case Some{c} Some{m}:
      Refused{id, c, m}
    case c m:
      Unread{"the error has no integer code or no message"}

def back.has(
  id: Value.Json,
  has_result: Bool,
  result: Value.Json,
  has_error: Bool,
  code: Maybe<&2, String>,
  message: Maybe<&2, String>
) -> Reply:
  match has_result has_error:
    case True{} False{}:
      Got{id, result}
    case False{} True{}:
      back.refused(id, code, message)
    case r e:
      Unread{"a reply must hold exactly one of result and error"}

# what a reply says, from its fields
def back.decide(byte: Back) -> Reply:
  match byte:
    case Back{v2, id, has_result, result, has_error, code, message}:
      Bool.pick(Reply, v2,
        back.has(id, has_result, result, has_error, code, message),
        Unread{"not a JSON-RPC 2.0 reply"})

def back.code(meth: Maybe<&2, String>) -> Maybe<&2, String>:
  match meth:
    case None{}:
      None{}
    case Some{+raw}:
      Bool.pick(Maybe<&2, String>, int.text(raw), Some{raw}, None{})

# the fields of one decoded reply
def back(+val: Value.Json) -> Back:
  Back{is.v2(Json.as_str(Json.get(val, "jsonrpc"))), Json.get(val, "id"),
    Json.has(val, "result"), Json.get(val, "result"), Json.has(val, "error"),
    back.code(Json.as_num(Json.get(Json.get(val, "error"), "code"))),
    Json.as_str(Json.get(Json.get(val, "error"), "message"))}

def read.parsed(meth: Maybe<&2, Value.Json>) -> Reply:
  match meth:
    case None{}:
      Unread{"the reply is not JSON"}
    case Some{v}:
      back.decide(back(v))

# what one reply's text says
def read(text: String) -> Reply:
  read.parsed(Json.parse(text))
