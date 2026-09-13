{
  description = "Quickshell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    quickshell.url = "github:quickshell-mirror/quickshell";
  };

  outputs = { self, nixpkgs, flake-utils, quickshell }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        backendqs = pkgs.rustPlatform.buildRustPackage {
          pname = "backendqs";
          version = "0.1.0";
          src = ./backendqs;

          cargoLock = {
            lockFile = ./backendqs/Cargo.lock;
            allowBuiltinFetchGit = true;
          };

          nativeBuildInputs = [ pkgs.makeWrapper pkgs.pkg-config pkgs.cmake ];
          buildInputs = [ pkgs.alsa-lib pkgs.libopus pkgs.dbus pkgs.xz pkgs.bzip2 pkgs.systemd ];

          postInstall = ''
            wrapProgram $out/bin/backendqs \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.pandoc pkgs.tectonic pkgs.poppler-utils pkgs.rink pkgs.cliphist pkgs.wl-clipboard pkgs.libarchive pkgs.coreutils (pkgs.tesseract.override { enableLanguages = [ "eng" ]; }) ]} \
              --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.alsa-lib pkgs.libopus pkgs.dbus pkgs.systemd ]}
          '';
        };

        qs = quickshell.packages.${system}.default;
        configPath = "${self}/ui";

        leninshell = pkgs.symlinkJoin {
          name = "leninshell";
          paths = [ qs ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            rm $out/bin/quickshell
            makeWrapper ${qs}/bin/quickshell $out/bin/leninshell \
              --add-flags "--path ${configPath}" \
              --prefix PATH : "${backendqs}/bin"

            makeWrapper $out/bin/leninshell $out/bin/lenin-launcher \
              --add-flags "ipc call appLauncher toggle"

            makeWrapper $out/bin/leninshell $out/bin/lenin-lock \
              --add-flags "ipc call lock lock"

            makeWrapper $out/bin/leninshell $out/bin/lenin-keepass \
              --add-flags "ipc call keepass toggle"

            makeWrapper $out/bin/leninshell $out/bin/lenin-screenshot \
              --add-flags "ipc call screenshot take"

            makeWrapper $out/bin/leninshell $out/bin/lenin-rsvp \
              --add-flags "ipc call rsvp toggle"
          '';
        };

      in
      {
        packages = {
          inherit backendqs leninshell;
          default = leninshell;
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
            pkg-config
            cmake
            alsa-lib
            libopus
            dbus
            xz
            bzip2
            systemd
            cliphist
            wl-clipboard
            libarchive
            (tesseract.override { enableLanguages = [ "eng" ]; })
          ];
        };
      }
    );
}
