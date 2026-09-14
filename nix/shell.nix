{ mkShell
, cargo
, rustc
, rustfmt
, clippy
, pandoc
, tectonic
, poppler-utils
, pkg-config
, cmake
, alsa-lib
, libopus
, dbus
, xz
, bzip2
, systemd
, cliphist
, wl-clipboard
, libarchive
, tesseract
}:

mkShell {
  buildInputs = [
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
}
