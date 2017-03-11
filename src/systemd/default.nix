{ runCommand

, varDirectory
, dwnLauncher
}:

runCommand "dwn-systemd" {
  socket = "${varDirectory}/dwn.socket";
  launcher = dwnLauncher;
} ''
  mkdir -p $out
  substituteAll ${./dwn.service.in} $out/dwn.service
''
