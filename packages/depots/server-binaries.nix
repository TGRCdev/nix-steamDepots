# Fixup and patch binaries to work without steam-run
{
  pkgsi686Linux,
  stdenvNoCC,
  steamPackages,
  fetchDepot,
  server-binaries-unpatched,
}:
stdenvNoCC.mkDerivation {
  name = "garrys-mod-dedicated-server-linux-bins";
  src = server-binaries-unpatched;

  buildInputs = [
    steamPackages.steam-runtime
  ];
  nativeBuildInputs = [
    pkgsi686Linux.autoPatchelfHook
  ];

  buildPhase = ''
    cp -r $src $out
    chmod +w $out
    echo 4000 > $out/steam_appid.txt
  '';

  preFixupPhases = [ "autoPatchelfPathsPhase" ];
  # Find dependencies from the runtime and link them
  autoPatchelfPathsPhase = ''
    addAutoPatchelfSearchPath ${steamPackages.steam-runtime}/usr/lib/i386-linux-gnu/
    addAutoPatchelfSearchPath ${steamPackages.steam-runtime}/lib/i386-linux-gnu/
    addAutoPatchelfSearchPath $out/bin
  '';
  # AFAIK these aren't needed for the headless server
  autoPatchelfIgnoreMissingDeps = [
    "libtier0.so"
    "libvstdlib.so"
  ];
}