{ lib, writeScriptBin, socat, callPackage, runCommand }: rec {
  mvnDeps = callPackage ./deps.nix {};
  quote = s: let qs = lib.replaceStrings ["\"" "\\"] ["\\\"" "\\\\"] "${s}";
              in if (lib.isInt s) then
                toString s
              else if (lib.isBool s) then
                if s then "true" else false
              else
                ''"${qs}"'';
  indent-quote = indent: s: "${indent}${quote s}";

  deref = target: s: (
   "local " + target + "=\"$" + "(eval echo \\\"\\$" + "{" + s + "}\\\")\""
  );

  indent-list-raw = indent: lines:
    lib.concatStringsSep "\n${indent}" lines;

  indent-list = indent: lst:
    (indent-list-raw indent (map (toEdnIndent indent) lst));

  indent-map = indent: attrs: indent-list-raw indent (lib.mapAttrsToList (k: v:
    ":${k} ${toEdnIndent (indent + "  ") v}"
  ) attrs);

  toEdnIndent = indent: val:
    let indent-inner = indent + " "; in
    if (! (lib.isDerivation val)) && (lib.isAttrs val) then
      "{" + indent-map indent-inner val + "}"
    else if lib.isList val then
      "[" + indent-list indent-inner val + "]"
    else "${quote val}";

  toEdn = val: toEdnIndent "" val;

  dwnComponent = id: type: constructor: classpath: ''
  {:id ${id}
   :type ${type}
   :constructor ${constructor}
   :classpath #jvm.classpath/list [
    ${indent-list "  " classpath}]}
  '';

  sourceDir = p: "${p}/";

  ednCommand = cmd: args: ''
    [:${cmd} ${args}]
  '';

  ednComponentCommand = cmd: name: args:
    ednCommand cmd ''"${name}" ${args}'';

  listClasspath = classpath:
    "#jvm.classpath/list ${toEdnIndent '' '' classpath}";
  fileClassPath = classpath:
    "#jvm.classpath/file ${quote classpath}";

  loadComponentCommand = name: sym: config: classpath:
    ednComponentCommand "load-component" name ''
      ${sym}
      ${toEdnIndent " " config}
      ${classpath}
    '';

  loadPluginCommand = name: sym: config: classpath:
    ednComponentCommand "load-plugin" name ''
      ${sym}
      ${toEdnIndent " " config}
      ${classpath}
    '';

  startComponentCommand = name:
    ednComponentCommand "start-component" name "";

  pluginCommand = name: cmd: args:
    ednComponentCommand "plugin-cmd" name ''
      :${cmd} ${args}
    '';

  commandRunner = dwn: script-name: edn-cmd: writeScriptBin script-name ''
    #!/bin/sh
    ${(bin dwn).client} <<CMDEOF
      ${edn-cmd}
    CMDEOF
  '';

  bin = callPackage ./util-instantiated.nix { };

  collectBinFolders = name: drvs: runCommand name (let
    attrs = lib.listToAttrs (map (drv:
      {name=drv.name;value=drv;}
    ) drvs);
  in (attrs // {
    inherit name;
    dwn_command_list = map (d: d.name) drvs;    
  })) ''
    mkdir -p $out/bin
    cd $out/bin
    for drv in $dwn_command_list; do
      ${deref "drvPath" "$drv"}
      for f in $drvPath/bin/*; do
        ln -s $f "$drv-$(basename $f)"
      done
    done
  '';

}
