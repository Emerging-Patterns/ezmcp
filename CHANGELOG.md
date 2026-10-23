# Changelog

## 0.1.0 (2026-10-23)


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
