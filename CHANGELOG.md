# Changelog

## [0.5.0](https://github.com/Emerging-Patterns/ezmcp/compare/v0.4.0...v0.5.0) (2026-11-16)


### Bug Fixes

* **deps:** ezjson 1.5.0, ezhttp 0.26.0 ([#26](https://github.com/Emerging-Patterns/ezmcp/issues/26)) ([68ce3c4](https://github.com/Emerging-Patterns/ezmcp/commit/68ce3c43302b120c2434cb777d8cbebbdf560f3a))

## [0.4.0](https://github.com/Emerging-Patterns/ezmcp/compare/v0.3.0...v0.4.0) (2026-11-16)


### ⚠ BREAKING CHANGES

* **lint:** the serves that take a context take their address as one `addr: String & U32` pair, `(host, port)`, where they took `host, port`:
    - `http.serve_with(~C, ~run, ~srv, ~path, ~origins, ctx, addr: String & U32, limit, max)`
    - `http.serve_from(~C, ~srv, ~run, ~path, ~origins, ctx, addr: String & U32, limit, max)`
    - `http.serve_forever_with(~C, ~run, ~srv, ~path, ~origins, ctx, addr: String & U32, max)`
    - `http.serve_forever_from(~C, ~srv, ~run, ~path, ~origins, ctx, addr: String & U32, max)`

### Features

* **lint:** ez 1.16.0, bolt 1.65.0; serves take their address as a (host, port) pair ([#23](https://github.com/Emerging-Patterns/ezmcp/issues/23)) ([ec9fdf7](https://github.com/Emerging-Patterns/ezmcp/commit/ec9fdf7204c6494f9b381199482b16f38128bf50))

## [0.3.0](https://github.com/Emerging-Patterns/ezmcp/compare/v0.2.0...v0.3.0) (2026-11-09)


### Bug Fixes

* **deps:** import ezjson and ezhttp by hub name ([#20](https://github.com/Emerging-Patterns/ezmcp/issues/20)) ([fb7176c](https://github.com/Emerging-Patterns/ezmcp/commit/fb7176c7e17179aefcfca88869c5cbdbb6c0bef0))

## [0.2.0](https://github.com/Emerging-Patterns/ezmcp/compare/v0.1.0...v0.2.0) (2026-11-07)


### ⚠ BREAKING CHANGES

* the type `Server.Tool` and its constructor `Tool{...}` are renamed `Server.ToolSpec` and `ToolSpec{...}`. ezmcp now imports ezhttp at 2b918f5 (0x7367809738fddd234b8d2bed772ad2cf) instead of cab153b.

### Features

* **nix:** build and check on x86_64-linux, aarch64-linux and aarch64-darwin ([#15](https://github.com/Emerging-Patterns/ezmcp/issues/15)) ([c8d39ce](https://github.com/Emerging-Patterns/ezmcp/commit/c8d39cebc58c7a967d4b22f0dd8fd97e60f23c45))
* rename Server.Tool to Server.ToolSpec, so ezmcp checks on bend 2.0.40 ([#18](https://github.com/Emerging-Patterns/ezmcp/issues/18)) ([d817402](https://github.com/Emerging-Patterns/ezmcp/commit/d8174023acb36b15d5443e64d678df9a1c43951f))

## 0.1.0 (2026-10-27)


### ⚠ BREAKING CHANGES

* `http.serve_with` and `http.serve_forever_with` take a last argument `max`, the most connections served at once (0: no limit). `http.serve` and `http.serve_forever` serve connections concurrently with no limit; pass `max` 1 to a `_with` serve to keep one call at a time. An https endpoint's TLS reads `BEND_LIBSSL`; `EZ_LIBSSL` is gone.

### Features

* let a tool runner refuse a call with a JSON-RPC error ([#5](https://github.com/Emerging-Patterns/ezmcp/issues/5)) ([1ca72a5](https://github.com/Emerging-Patterns/ezmcp/commit/1ca72a5934855442d60c15a38206ff2f067ebfb4))
* MCP 2025-06-18 servers and clients under a spec cited from the protocol ([#1](https://github.com/Emerging-Patterns/ezmcp/issues/1)) ([d8bdf40](https://github.com/Emerging-Patterns/ezmcp/commit/d8bdf40d35dd99262ce51e7e6bc27746079e1da5))
* OpenAPI documents as tool tables, and servers built at run time ([#12](https://github.com/Emerging-Patterns/ezmcp/issues/12)) ([f6aea73](https://github.com/Emerging-Patterns/ezmcp/commit/f6aea736498c9976bb463b31455395c7255f9769))
* serve HTTP on ezhttp's serve_with, a fork per connection ([#10](https://github.com/Emerging-Patterns/ezmcp/issues/10)) ([fe28cca](https://github.com/Emerging-Patterns/ezmcp/commit/fe28cca3cbc1cecf788141c0237c58cc79ded307))
* serve with a context the runner is given on every call ([#6](https://github.com/Emerging-Patterns/ezmcp/issues/6)) ([3c1af3a](https://github.com/Emerging-Patterns/ezmcp/commit/3c1af3a8975b34ccf9853e8e3a36468f536851b1))
* speak MCP 2025-03-26, 2025-06-18 and 2025-11-25 ([#4](https://github.com/Emerging-Patterns/ezmcp/issues/4)) ([fdfeec6](https://github.com/Emerging-Patterns/ezmcp/commit/fdfeec67c49fc31d8e9ca34103e517b0e2f98a64))


### Bug Fixes

* **deps:** ezhttp v0.14.0 ([#3](https://github.com/Emerging-Patterns/ezmcp/issues/3)) ([e49a147](https://github.com/Emerging-Patterns/ezmcp/commit/e49a147a1bb06cefd901739cb9931bcdf0c36169))

## Changelog
