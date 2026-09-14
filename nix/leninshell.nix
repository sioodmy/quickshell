{ symlinkJoin
, makeWrapper
, qs
, backendqs
, configPath
}:

symlinkJoin {
  name = "leninshell";
  paths = [ qs ];
  buildInputs = [ makeWrapper ];
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
}
