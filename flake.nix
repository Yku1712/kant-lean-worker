{
  description = "kant-lean-worker: Lean 4 node for Solfunmeme / ERDFa";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            elan
            git
            python3
            curl
          ];
          shellHook = ''
            echo "Welcome to the kant-lean-worker dev shell."
            echo "Run 'lake build' then './test.sh' to verify."
          '';
        };
      });
}
