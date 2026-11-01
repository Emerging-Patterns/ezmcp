# ezmcp's laws. Each guarantee is one file under laws/, its prose on top and
# its quantified laws under it, proved by the file of the same name under
# proofs/; LAWS.bend and PROOF.bend only import them. The gate: the first
# line `bend PROOF.bend` prints is exactly `ALL PROOFS CHECK`. Tests and
# fixtures are never evidence for a guarantee; what ezmcp cannot prove is
# said where it is assumed, on the code (`# Trusted, not proved:`). A
# guarantee whose prose says it is pending is proved only in part, and is
# not guaranteed until the rest is.
#
# ezmcp speaks three revisions of the Model Context Protocol: 2025-03-26,
# 2025-06-18 and 2025-11-25. Every guarantee comes from a normative
# statement of one of them, or of JSON-RPC 2.0, which MCP builds on, and
# cites its section and quotes the requirement (MUST, MUST NOT, SHOULD,
# MAY), then says what ezmcp does about it. Sections are cited by their path
# under <https://modelcontextprotocol.io/specification/>: a path that starts
# with a revision, as `2025-03-26/basic/lifecycle#initialization`, is that
# revision's page and anchor, and a bare path, as
# `basic/lifecycle#initialization`, is 2025-06-18's, whose words for that
# requirement 2025-03-26 and 2025-11-25 share unless the guarantee cites
# theirs. `schema.json` is 2025-06-18's schema,
# <https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/schema/2025-06-18/schema.json>,
# and `JSON-RPC §N` is a section of <https://www.jsonrpc.org/specification>.
#
# What differs between the three for the tools-only, stateless subset ezmcp
# serves is small, and each difference is a guarantee: 2025-03-26 receives
# JSON-RPC batches (laws/BatchesActInOrder.bend,
# laws/BatchPostsAnswered.bend) and has no `structuredContent`
# (laws/OldRevisionDropsStructuredContent.bend); 2025-06-18 adds the
# `MCP-Protocol-Version` header (laws/UnsupportedVersionAnswered400.bend,
# laws/RevisionFromVersionHeader.bend); 2025-11-25 names the 403 for a
# refused `Origin` (laws/ForeignOriginsAnswered403.bend). A message is read
# by a revision: over HTTP the one its `MCP-Protocol-Version` names, or
# 2025-03-26 when it names none (laws/RevisionFromVersionHeader.bend); over
# stdio the one the server answered the stream's last `initialize` with, and
# the latest before any (laws/StreamKeepsNegotiatedRevision.bend).
#
# The guarantees are about the pure modules: `src/rpc.bend` (JSON-RPC
# messages), `src/server.bend` (a server's answers), `src/web.bend` (the
# streamable HTTP transport's decisions), `src/line.bend` (the stdio
# transport's decisions), `src/sse.bend` and `src/client.bend` (the client
# side), and `src/openapi.bend` (an OpenAPI document as a tool table, and a
# tool call as an HTTP request). They do no IO, so the law files import them
# and nothing else. `src/io.bend` runs the effects on ezhttp and Base and
# acts on those modules' answers, and holds the one effect of ezmcp's own, a
# read of stdin; both are trusted in src/io.bend. `main.bend` names them:
# each of its pure names is a module's function and no more, so it carries
# no law of its own: bolt's `coverage` rule, an error in `bolt.bend`, flags
# the undotted ones, and each carries a `# noqa: L001` naming the function
# it re-exports.
#
# The guarantees' families each open with what the family is about:
# laws/RequestsCarryValidId.bend (JSON-RPC messages),
# laws/InitializeGivesServerInfo.bend (the lifecycle),
# laws/ToolsListGivesTable.bend (tools), laws/PostsAnsweredWithJson.bend
# (streamable HTTP), laws/LinesSplitAtNewlines.bend (stdio),
# laws/ClientRequestsCarryId.bend (the client) and
# laws/OperationsFromPaths.bend (OpenAPI).
#
# One deliberate departure from `schema.json`: its `JSONRPCError` requires
# an `id` that is a string or an integer, but JSON-RPC §5 requires
# `"id": null` in the error for a message whose id could not be read (a
# parse error, or an invalid request with no valid id). ezmcp follows
# JSON-RPC there (laws/BadRequestIdIsInvalid.bend,
# laws/UnparsedTextIsParseError.bend, laws/InvalidRequestsFault.bend), as
# MCP's own SDKs do; `basic/transports#sending-messages-to-the-server`
# allows such an error "that has no `id`" in an HTTP 400 body.
#
# What these revisions require of features ezmcp does not implement, or
# deliberately does not meet, is listed with each section under "Not
# implemented" in docs/SPEC.md. Commits before these files name guarantees
# by the requirement IDs of docs/SPEC.md, the table these files replaced.
import Base
import ./laws/ArgumentsChecked.bend as ArgumentsChecked
import ./laws/BadInputAnswered400.bend as BadInputAnswered400
import ./laws/BadRequestIdIsInvalid.bend as BadRequestIdIsInvalid
import ./laws/BadToolArgumentsRefused.bend as BadToolArgumentsRefused
import ./laws/BatchPostsAnswered.bend as BatchPostsAnswered
import ./laws/BatchesActInOrder.bend as BatchesActInOrder
import ./laws/BlankLinesGetNothing.bend as BlankLinesGetNothing
import ./laws/CallsBuildRequests.bend as CallsBuildRequests
import ./laws/CapabilitiesFromToolTable.bend as CapabilitiesFromToolTable
import ./laws/ClientInitializesWithLatest.bend as ClientInitializesWithLatest
import ./laws/ClientPostHeaders.bend as ClientPostHeaders
import ./laws/ClientReadsJsonOrStream.bend as ClientReadsJsonOrStream
import ./laws/ClientReadsReplies.bend as ClientReadsReplies
import ./laws/ClientReadsVersion.bend as ClientReadsVersion
import ./laws/ClientRequestsCarryId.bend as ClientRequestsCarryId
import ./laws/DescriptionsFromOperations.bend as DescriptionsFromOperations
import ./laws/ErrorsHaveIntegerCode.bend as ErrorsHaveIntegerCode
import ./laws/ForeignOriginsAnswered403.bend as ForeignOriginsAnswered403
import ./laws/InitializeGivesServerInfo.bend as InitializeGivesServerInfo
import ./laws/InvalidRequestsFault.bend as InvalidRequestsFault
import ./laws/KnownToolCallsRun.bend as KnownToolCallsRun
import ./laws/LinesDecodedAsUtf8.bend as LinesDecodedAsUtf8
import ./laws/LinesSplitAtNewlines.bend as LinesSplitAtNewlines
import ./laws/LocalRefsResolved.bend as LocalRefsResolved
import ./laws/MessagesAreJsonrpc2.bend as MessagesAreJsonrpc2
import ./laws/MessagesWrittenAsLines.bend as MessagesWrittenAsLines
import ./laws/NotificationsAnswered202.bend as NotificationsAnswered202
import ./laws/NotificationsGetNoReply.bend as NotificationsGetNoReply
import ./laws/OldRevisionDropsStructuredContent.bend as OldRevisionDropsStructuredContent
import ./laws/OperationsFromPaths.bend as OperationsFromPaths
import ./laws/OtherMethodsAnswered405.bend as OtherMethodsAnswered405
import ./laws/OtherPathsAnswered404.bend as OtherPathsAnswered404
import ./laws/ParametersBecomeProperties.bend as ParametersBecomeProperties
import ./laws/ParametersMergedByNameAndIn.bend as ParametersMergedByNameAndIn
import ./laws/PingAnswersEmpty.bend as PingAnswersEmpty
import ./laws/PostsAnsweredWithJson.bend as PostsAnsweredWithJson
import ./laws/ProtocolVersionNegotiated.bend as ProtocolVersionNegotiated
import ./laws/RefusedCallsAnswerErrors.bend as RefusedCallsAnswerErrors
import ./laws/RepliesCarryRequestId.bend as RepliesCarryRequestId
import ./laws/RepliesHaveResultOrError.bend as RepliesHaveResultOrError
import ./laws/RequestBodyBecomesProperty.bend as RequestBodyBecomesProperty
import ./laws/RequestsCarryValidId.bend as RequestsCarryValidId
import ./laws/ResponsesGetNoReply.bend as ResponsesGetNoReply
import ./laws/RevisionFromVersionHeader.bend as RevisionFromVersionHeader
import ./laws/SchemasMappedToJsonSchema.bend as SchemasMappedToJsonSchema
import ./laws/StreamKeepsNegotiatedRevision.bend as StreamKeepsNegotiatedRevision
import ./laws/StructuredResultsCarryText.bend as StructuredResultsCarryText
import ./laws/ToolNamesFromOperations.bend as ToolNamesFromOperations
import ./laws/ToolResultsHoldContent.bend as ToolResultsHoldContent
import ./laws/ToolsListGivesTable.bend as ToolsListGivesTable
import ./laws/UnknownMethodsNotFound.bend as UnknownMethodsNotFound
import ./laws/UnknownToolsRefused.bend as UnknownToolsRefused
import ./laws/UnparsedTextIsParseError.bend as UnparsedTextIsParseError
import ./laws/UnsupportedVersionAnswered400.bend as UnsupportedVersionAnswered400
