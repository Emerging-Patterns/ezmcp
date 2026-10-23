{
  description = "ezmcp: Model Context Protocol for Bend 2";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  # bendlang/bend's flake at the commit that packages 2.0.38 (the v2.0.38 tag
  # may still package 2.0.37)
  inputs.bend = {
    url = "github:bendlang/bend/042e797ebd1cfc060603e2682879909fe86fa8c2";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.ez = {
    url = "github:Emerging-Patterns/ez";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.bend.follows = "bend";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      version = "0.0.0"; # x-release-please-version
      ez = inputs.ez.lib.${system};
      ezBin = inputs.ez.packages.${system}.default;
      bend = inputs.bend.packages.${system}.default;
      bolt = ez.toolPackage { name = "bolt"; src = self; inherit bend; wrapFlags = ez.rtsFlags bend [ "--gpu" "off" ]; };
      bend-cc = ez.bend-cc;
      llvm = pkgs.llvmPackages_19;
    in {
      packages.${system} = {
        inherit bend bend-cc;
        ez = ezBin;
        inherit bolt;
      };

      checks.${system} = {
        proofs = ez.mkProofs { ez = ezBin; src = self; };
        # examples/demo on the C lane, over stdio and over HTTP on loopback:
        # initialize, notifications/initialized, tools/list, tools/call (a
        # result, a tool error, an unknown tool, a runner's protocol error)
        # and a body that is not JSON,
        # under 2025-06-18; then a 2025-03-26 session (a batch, a tool result
        # with no structuredContent) and a revision ezmcp does not speak;
        # then the context-carrying serves over both transports (examples/demo
        # with a prefix), the HTTP one stopping after its connection limit;
        # then examples/client runs a session against it. A smoke run, not
        # evidence for any SPEC.md row.
        smoke = pkgs.runCommand "ezmcp-smoke" {
          nativeBuildInputs = [ bend llvm.clang pkgs.curl ];
          BEND_LIB = ez.bendLib ./ez.lock.toml;
          BEND_NO_TELEMETRY = "1";
        } ''
          export HOME=$TMPDIR CC=${llvm.clang}/bin/clang
          cp -r ${self} src && chmod -R u+w src && cd src/examples/demo
          bend main.bend -o demo
          init='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke","version":"1"}}}'
          note='{"jsonrpc":"2.0","method":"notifications/initialized"}'
          list='{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
          add='{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"add","arguments":{"a":2,"b":40}}}'
          bad='{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"add","arguments":{"a":"x"}}}'
          nope='{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"nope"}}'
          refused='{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"echo","arguments":{"text":3}}}'
          check() {
            echo "$1" | grep -qF '"id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{"listChanged":false}}' || exit 1
            echo "$1" | grep -qF '"name":"add","description":"Add two integers"' || exit 1
            echo "$1" | grep -qF '"id":3,"result":{"content":[{"type":"text","text":"{\"sum\":42}"}],"structuredContent":{"sum":42},"isError":false}' || exit 1
            echo "$1" | grep -qF '"id":4,"result":{"content":[{"type":"text","text":"add: a and b must be non-negative integers"}],"isError":true}' || exit 1
            echo "$1" | grep -qF '"id":5,"error":{"code":-32602,"message":"Unknown tool: nope"}' || exit 1
            echo "$1" | grep -qF '"id":null,"error":{"code":-32700,"message":"Parse error"}' || exit 1
            echo "$1" | grep -qF '"id":6,"error":{"code":-32602,"message":"echo: text must be a string"}' || exit 1
          }
          got=$(printf '%s\n' "$init" "$note" "" "$list" "$add" "$bad" "$nope" '{oops' "$refused" | ./demo stdio)
          echo "$got"
          [ "$(echo "$got" | wc -l)" = 7 ] || exit 1
          check "$got"
          old='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"smoke","version":"1"}}}'
          batch='[{"jsonrpc":"2.0","method":"notifications/initialized"},{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"add","arguments":{"a":1,"b":2}}},{"jsonrpc":"2.0","id":8,"method":"ping"}]'
          got=$(printf '%s\n' "$old" "$batch" '[]' | ./demo stdio)
          echo "$got"
          echo "$got" | grep -qF '"protocolVersion":"2025-03-26"' || exit 1
          echo "$got" | grep -qxF '[{"jsonrpc":"2.0","id":7,"result":{"content":[{"type":"text","text":"{\"sum\":3}"}],"isError":false}},{"jsonrpc":"2.0","id":8,"result":{}}]' || exit 1
          echo "$got" | grep -qF '"id":null,"error":{"code":-32600,"message":"Invalid Request: empty batch"}' || exit 1
          got=$(printf '%s\n' "$init" "$batch" | ./demo stdio)
          echo "$got" | grep -qF '"id":null,"error":{"code":-32600,"message":"Invalid Request: not a JSON-RPC object"}' || exit 1
          ./demo http 18765 100 &
          demo=$!
          for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:18765/ && break; sleep 0.1; done
          post() {
            curl -s -w ' %{http_code}\n' -H 'Content-Type: application/json' \
              -H 'Accept: application/json, text/event-stream' \
              -H "MCP-Protocol-Version: ''${2:-2025-06-18}" -d "$1" http://127.0.0.1:18765/mcp
          }
          bare() {
            curl -s -w ' %{http_code}\n' -H 'Content-Type: application/json' \
              -H 'Accept: application/json, text/event-stream' -d "$1" http://127.0.0.1:18765/mcp
          }
          http=$(for b in "$init" "$note" "$list" "$add" "$bad" "$nope" '{oops' "$refused"; do post "$b"; done)
          echo "$http"
          check "$http"
          echo "$http" | grep -qx ' 202' || exit 1
          echo "$http" | grep -q 'Parse error"}} 400$' || exit 1
          [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:18765/mcp)" = 405 ] || exit 1
          b=$(bare "$batch"); echo "$b"
          echo "$b" | grep -qF '{"jsonrpc":"2.0","id":7,"result":{"content":[{"type":"text","text":"{\"sum\":3}"}],"isError":false}}' || exit 1
          echo "$b" | grep -q '}] 200$' || exit 1
          [ "$(bare '[{"jsonrpc":"2.0","method":"notifications/initialized"}]')" = ' 202' ] || exit 1
          post "$add" 2025-11-25 | grep -qF '"structuredContent":{"sum":42}' || exit 1
          post "$add" 2026-07-28 | grep -q ' 400$' || exit 1
          kill $demo
          # the context-carrying serves hand the prefix to the runner
          echo1='{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"echo","arguments":{"text":"hi"}}}'
          printf '%s\n' "$echo1" | ./demo stdio '> ' | grep -qF '"text":"> hi"' || exit 1
          ./demo http 18766 3 'H: ' &
          ctxd=$!
          for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:18766/ && break; sleep 0.1; done
          curl -s -H 'MCP-Protocol-Version: 2025-06-18' -d "$echo1" http://127.0.0.1:18766/mcp | grep -qF '"text":"H: hi"' || exit 1
          [ "$(curl -s -o /dev/null -w '%{http_code}' -d '{oops' http://127.0.0.1:18766/mcp)" = 400 ] || exit 1
          wait $ctxd
          ./demo http 18765 100 &
          demo=$!
          for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:18765/ && break; sleep 0.1; done
          cd ../client
          bend main.bend -o client
          ses=$(./client http://127.0.0.1:18765/mcp add '{"a":5,"b":6}')
          echo "$ses"
          echo "$ses" | grep -qx 'initialized accepted: True' || exit 1
          echo "$ses" | grep -qF 'got 3 {"content":[{"type":"text","text":"{\"sum\":11}"}]' || exit 1
          kill $demo
          touch $out
        '';
        lint = ez.mkLint { src = self; };
      };

      devShells.${system}.default = ez.mkShell {
        src = self;
        packages = [
          bend
          bend-cc
          ezBin
        ];
      };
    };
}
