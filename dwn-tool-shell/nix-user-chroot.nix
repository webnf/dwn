{ stdenv, fetchFromGitHub }:

stdenv.mkDerivation {

  name = "nix-user-chroot-2c52b5f";

  src = fetchFromGitHub {
    owner = "matthewbauer";
    repo = "nix-user-chroot";
    rev = "2c52b5f3174e382c2bfdd9e61f3e4a1200077b93";
    sha256 = "139ixrg5ihrgsmi2nl1ws3xmi0vqwl5nwfijrggg02wlbiqvdiwq";
  };

  ## hack to use when /nix/store is not available
  # postFixup = ''
  #   exe=$out/bin/nix-user-chroot
  #   patchelf \
  #     --set-interpreter .$(patchelf --print-interpreter $exe) \
  #     --set-rpath $(patchelf --print-rpath $exe | sed 's|/nix/store/|./nix/store/|g') \
  #     $exe
  # '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin/
    cp nix-user-chroot $out/bin/nix-user-chroot
    runHook postInstall
  '';

}
