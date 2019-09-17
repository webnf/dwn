self: super:

with self.lib;

{
  subPath = path: drv: self.runCommand (drv.name + "-" + replaceStrings ["/"] ["_"] path) {
    inherit path;
  } ''
    mkdir -p $out/$(dirname $path)
    ln -s ${drv} $out/$path
  '';

  uniqifyingSymlinkJoin = name: classpath: self.runCommand name {
    inherit classpath;
  } ''
    mkdir -p $out/share/java
    cd $out/share/java
    for c in $classpath; do
      local targetOrig=$out/share/java/$(stripHash $c)
      local target=$targetOrig
      local cnt=0
      while [ -L $target ]; do
        target=$targetOrig-$cnt
        cnt=$(( cnt + 1 ))
      done
      ln -s $c $target
    done
  '';

}
