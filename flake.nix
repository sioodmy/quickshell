{
  description = "Quickshell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    quickshell.url = "github:quickshell-mirror/quickshell";
    qml-niri = {
      url = "github:imiric/qml-niri/93e603901bed2c4465d5675ae43fd52b7f7c4adf";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.quickshell.follows = "quickshell";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, quickshell, qml-niri, treefmt-nix }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      treefmtEval = forAllSystems (system: treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./nix/treefmt.nix);
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          backendqs = pkgs.callPackage ./nix/backendqs.nix { };
          qs = qml-niri.packages.${system}.quickshell;
          leninshell = pkgs.callPackage ./nix/leninshell.nix {
            inherit qs backendqs;
            configPath = "${self}/ui";
          };
        in
        {
          inherit backendqs leninshell;
          default = leninshell;
        }
      );

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.callPackage ./nix/shell.nix { };
        }
      );

      formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);
    };
}
