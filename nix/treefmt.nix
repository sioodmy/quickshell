{ pkgs, ... }:

{
  projectRootFile = "flake.nix";

  programs.nixpkgs-fmt.enable = true;
  programs.rustfmt.enable = true;
}
