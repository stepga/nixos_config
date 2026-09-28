{ lib
, stdenv
, makeWrapper
, bash
, coreutils
, gawk
, gnugrep
, iproute2
, nftables
, procps
, util-linux
}:

stdenv.mkDerivation {
  pname = "freifunk";
  version = "1.0";

  src = ./ff.sh;

  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
  ];

  installPhase = ''
    install -Dm755 "$src" "$out/bin/ff.sh"
  '';

  postInstall = ''
    wrapProgram "$out/bin/ff.sh" \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          coreutils
          gawk
          gnugrep
          iproute2
          nftables
          procps
          util-linux
        ]
      }
  '';

  meta = {
    description = "Run applications through the Freifunk network namespace";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
