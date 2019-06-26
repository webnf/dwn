{ runCommand, gcc }:

runCommand "user-mount-tools" {
  nativeBuildInputs = [
    gcc
  ];
} ''
  mkdir -p $out/bin
  gcc -o $out/bin/revertuid ${./revertuid.c}
  substituteAll ${./unshare-user-mounts.in} $out/bin/unshare-user-mounts
  chmod +x $out/bin/unshare-user-mounts
  fixupPhase
''
