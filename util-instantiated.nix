{ lib, runCommand, util }: dwn: rec {
  client = "${dwn}/bin/dwn-client";
  server = "${dwn}/bin/dwn-server";
  wait = "${dwn}/bin/dwn-wait-server";
  dwnCommands = name: cmds: runCommand name (cmds // {
    dwn_client = client;
    dwn_command_list = lib.mapAttrsToList (n: _: n) cmds;
  }) ''
    mkdir -p $out/bin
    cd $out/bin
    for cmd in $dwn_command_list; do
      ${util.deref "cmdForm" "$cmd"}
      cat > $cmd <<EOF
    #!/bin/sh
    $dwn_client <<IEOF
    $cmdForm
    IEOF
    EOF
      chmod +x $cmd
    done
  '';
}
