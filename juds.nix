{ stdenv, jdk, fetchFromGitHub, fetchurl, autoconf }:
let

  version = "0.96-alpha";

in stdenv.mkDerivation {
  name = "juds-${version}";
  src = fetchFromGitHub {
    owner = "mcfunley";
    repo = "juds";
    rev = "6621191ce0edded2cb7e8bdcac1985d17c054924";
    sha256 = "1dsmgh2r0pl5ca490fwkdh9kdlvgjy3r28wkyc8gra877z0pi28m";
  };
  nativeBuildInputs = [ jdk ];
  buildInputs = [ <nixpkgs/pkgs/build-support/setup-hooks/separate-debug-info.sh> ];
  outputs = [ "out" "debug" ];
  patches = [ ./0001-prepare-for-hardcoded-sopath.patch ];

  buildCommand = ''
    sopath="$out/lib/libunixdomainsocket.so"

    unpackPhase
    cd $sourceRoot
    patchPhase
    substituteInPlace com/etsy/net/UnixDomainSocket.java \
      --subst-var sopath

    mkdir -p $out/lib $out/src
    cp -R com $out/src/com

    javac -sourcepath $out/src -d $out/lib com/etsy/net/{JUDS,UnixDomainSocket,UnixDomainSocketClient,UnixDomainSocketServer}.java
    javah -sourcepath . -o $out/src/com/etsy/net/UnixDomainSocket.h com.etsy.net.UnixDomainSocket
    gcc -fPIC -O2 -shared -o $sopath $out/src/com/etsy/net/UnixDomainSocket.c

    fixupPhase
  '';
}
