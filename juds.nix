{ stdenv, jdk, fetchFromGitHub, fetchurl, autoconf }:
let

  version = "0.95";

in stdenv.mkDerivation {
  name = "juds-${version}";
  src = fetchFromGitHub {
    owner = "mcfunley";
    repo = "juds";
    rev = "3334ede781240fd52cbc06fdc84243a73c88ea95";
    sha256 = "0kizlvdax6jwnzvr6y4zfvgqxp6b02isr1bcijnmqhzs6kcdkvjg";
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
