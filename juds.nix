{ stdenv, jdk, fetchgit, autoconf }:
let

  version = "0.94";

in stdenv.mkDerivation rec {
  name = "juds-${version}.jar";
  src = fetchgit {
    url = "https://github.com/mcfunley/juds.git";
    rev = "3545035fc63aeccf3444b447e7959c7675381027";
    sha256 = "6072dc200f2820544830ddfafeee42beeb4f64697645de3e921fa5ad6684ddb9";
  };
  nativeBuildInputs = [ jdk autoconf ];
  phases = [ "unpackPhase" "configurePhase" "buildPhase" "installPhase" ];
  preConfigure = "sh autoconf.sh";
  buildPhase = ''
    make SHELL=${stdenv.shell} \
         M32="-m64" \
         PREFIX=$out \
         nativelib jar
  '';
  installPhase = ''
    cp ${name} $out
  '';
}
