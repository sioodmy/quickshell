{ lib
, rustPlatform
, makeWrapper
, pkg-config
, cmake
, alsa-lib
, libopus
, dbus
, xz
, bzip2
, systemd
, pandoc
, tectonic
, poppler-utils
, rink
, cliphist
, wl-clipboard
, libarchive
, coreutils
, tesseract
}:

rustPlatform.buildRustPackage {
  pname = "backendqs";
  version = "0.1.0";
  src = ../backendqs;

  cargoLock = {
    lockFile = ../backendqs/Cargo.lock;
    allowBuiltinFetchGit = true;
  };

  nativeBuildInputs = [ makeWrapper pkg-config cmake ];
  buildInputs = [ alsa-lib libopus dbus xz bzip2 systemd ];

  postInstall = ''
    wrapProgram $out/bin/backendqs \
      --prefix PATH : ${lib.makeBinPath [ pandoc tectonic poppler-utils rink cliphist wl-clipboard libarchive coreutils (tesseract.override { enableLanguages = [ "eng" ]; }) ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ alsa-lib libopus dbus systemd ]}
  '';
}
