# ezmcp

[Model Context Protocol](https://modelcontextprotocol.io/specification/2025-06-18)
servers and clients for [Bend 2](https://github.com/bendlang/bend).

Nothing is released yet.

## Guarantees

[SPEC.md](SPEC.md) lists every behavior ezmcp guarantees, each either proved
by a quantified law in `LAWS.bend` or named as a trusted assumption. A row
marked pending is not guaranteed yet. `nix flake check` runs the proof gate
(`bend PROOF.bend` must print exactly `ALL PROOFS CHECK` first) and bolt,
whose `trace` rule checks that SPEC.md and the laws agree.

## License

MIT, see [LICENSE](LICENSE).
