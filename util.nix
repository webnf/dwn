{ lib, writeScriptBin, socat, callPackage }: rec {
  mvnDeps = callPackage ./deps.nix {};
  quote = s: let qs = lib.replaceStrings ["\"" "\\"] ["\\\"" "\\\\"] "${s}";
              in if (lib.isInt s) then
                toString s
              else if (lib.isBool s) then
                if s then "true" else false
              else
                ''"${qs}"'';
  indent-quote = indent: s: "${indent}${quote s}";

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

  ednCommand = cmd: name: args: ''
    [:${cmd} "${name}"
     ${args}]
  '';

  loadComponentCommand = name: sym: config: classpath:
    ednCommand "load-component" name ''
      ${sym}
      ${toEdnIndent " " config}
       #jvm.classpath/list ${toEdnIndent " " classpath}
    '';

  startComponentCommand = name:
    ednCommand "start-component" name "";

  pluginCommand = name: cmd: args:
    ednCommand "plugin-cmd" name ''
      :${cmd} ${args}
    '';

  commandRunner = dwn: script-name: edn-cmd: writeScriptBin script-name ''
    #!/bin/sh
    ${dwn}/bin/dwn-client <<CMDEOF
      ${edn-cmd}
    CMDEOF
  '';

/*  commandRunner = dwn: name: cmd: args: writeScript "${name}-${cmd}" ''
    #!/bin/sh
    ${socat}/bin/socat -t 8 - tcp-connect:${dwn.host}:${dwn.port} <<EOF
    [:${cmd} "${name}" ${args}]
    EOF
  '';

  loadComponent = dwn: name: sym: config: classpath:
    commandRunner dwn name "load-component" ''
      ${sym} {
        ${indent-map "  " config}}
        [${indent-list "  "
           (map (p: "file:${p}")
                classpath)}]
    '';*/
}
