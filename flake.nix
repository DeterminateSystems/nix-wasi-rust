{
  description = "Nix WebAssembly plugin example";

  inputs = {
    nixpkgs.follows = "nix/nixpkgs";
    flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/*.tar.gz";
    nix.url = "github:DeterminateSystems/nix-src";
    fenix = {
      url = "https://flakehub.com/f/nix-community/fenix/0.1.*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    naersk = {
      url = "https://flakehub.com/f/nix-community/naersk/0.1.*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, ... }@inputs:
    let
      cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
      supportedSystems = [ "aarch64-darwin" "x86_64-linux" ];
      forAllSystems = f: inputs.nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              rustToolchain = with inputs.fenix.packages.${system};
                combine [
                  latest.rustc
                  latest.cargo
                  targets.wasm32-wasip1.latest.rust-std
                ];
            })
          ];
        };
        inherit system;
      });
    in
    {
      packages = forAllSystems ({ pkgs, system }: rec {
        default = nix-wasm-plugins;

        nix-wasm-plugins = with pkgs;
          (pkgs.callPackage inputs.naersk {
            cargo = pkgs.rustToolchain;
            rustc = pkgs.rustToolchain;
          }).buildPackage {
            pname = "nix-wasi-rust";
            version = "0.0.1";

            src = self;

            CARGO_BUILD_TARGET = "wasm32-wasip1";

            postInstall =
              ''
                for i in $out/bin/*.wasm; do
                  wasm-opt -O3 -o "$i" "$i"
                done
              '';

            buildInputs = [
              binaryen
            ];
          };
      });

      devShells = forAllSystems ({ pkgs, system }: rec {
        default = with pkgs; self.packages.${system}.default.overrideAttrs (attrs: {
          nativeBuildInputs = attrs.nativeBuildInputs ++ [
            rust-analyzer
            rustfmt
            clippy
          ];
        });
      });

      checks = forAllSystems ({ pkgs, system }: rec {
        build = self.packages.${system}.default;
        run =
          pkgs.runCommand "nix-wasi-rust-test-${system}"
          {
            buildInputs = [ inputs.nix.packages.${system}.nix ];
          }
          ''
            path=$(nix build --extra-experimental-features wasm-derivations --print-out-paths -L --store $TMPDIR/nix --impure --offline --expr 'derivation {
              name = "nix-wasi-builder-hello-test";
              system = "wasm32-wasip1";
              builder = ${self.packages.${system}.default}/bin/nix-wasi-builder-hello.wasm;
              passAsFile = [ "greeting" ];
              greeting = "Hello";
              args = [ "World!" ];
            }')
            [[ $(nix store cat --store $TMPDIR/nix $path) = "Hello World!" ]]
            touch $out
          '';
      });
    };
}
