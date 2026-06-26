{
  description = "Quickshell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";


  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        backendqs = pkgs.rustPlatform.buildRustPackage {
          pname = "backendqs";
          version = "0.1.0";
          src = ./backendqs;

          cargoLock = {
            lockFile = ./backendqs/Cargo.lock;
          };

          nativeBuildInputs = [ pkgs.makeWrapper ];

          postInstall = ''
            wrapProgram $out/bin/backendqs \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.pandoc pkgs.tectonic pkgs.poppler-utils pkgs.rink pkgs.cliphist ]}
          '';
        };

      in
      {
        packages = {
          backendqs = backendqs;
          default = backendqs;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            cargo
            rustc
            rustfmt
            clippy
            pandoc
            tectonic
            poppler-utils
          ];
        };
      }
    );
}
