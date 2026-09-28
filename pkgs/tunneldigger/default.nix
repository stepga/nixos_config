{ lib
, stdenv
, fetchFromGitHub
, cmake
, pkg-config
, libnl
}:

stdenv.mkDerivation {
  pname = "tunneldigger";
  version = "unstable-2026-09-28-9a9a427";

  src = fetchFromGitHub {
    owner = "wlanslovenija";
    repo = "tunneldigger";
    rev = "9a9a42741837115d99dd9c398a9a3976d81727d2";
    hash = "sha256-NoU+U5L+EO6L3NhjANNCmEngT6Sf2aJ7LdjX+rPrM74=";
  };

  sourceRoot = "source/client";

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    libnl
  ];

  cmakeFlags = [
    "-DUSE_LIBNL=ON"
  ];

  meta = {
    description = "L2TPv3 VPN tunneling solution";
    homepage = "https://github.com/wlanslovenija/tunneldigger";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.linux;
  };
}
