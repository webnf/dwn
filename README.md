DWN -- A Clojure launcher via Nix(OS)
=====================================

## Usage

For now, I can just refer you to #Philosophy##Could? and ask you to
consult the [Nix Manual](http://nixos.org/nix/manual/)

The entry path is `shell.nix -> default.nix -> packages.nix`

There is some interesting bootstrapping going on between
`deps.aether/default.nix` and `deps.expander/default.nix`, but
`project.nix` is already a fully formed project descriptor for the
`webnf.dwn` runtime library.

If you just want to jump in, try

```
curl https://nixos.org/nix/install | sh



```


# Philosophy

## Why?

Nix is a lazy, dynamically typed functional language, that is designed
to produce immutable filesets via build recipes. It is also a package
manager for software on Linux, OSX, Windows and Hurd. It lets you use
all of that software to complete your build recipes and it has awesome
ways for distributing the result of your own build recipes.

Clojure, on the other hand is a strict, dynamically typed functional
language, that is designed to utilize immutability in
application-level code. This means, that by using Nix, we can build a
rock solid foundation to run clojure on, including options for
spinning it up in the cloud, in containers or vms, via NixOS.

Clojure goes onto Nix, like jam onto bread. Or, as Alex Miller put
it at EuroClojure '17: "They are cut from the same cloth".

Jam and bread do call for butter, though, i.e. tooling to bring out
the flavor.

## How?

Like Nix(OS), DWN isn't peanut butter. It isn't very
opinionated. Instead, it's a plain, fatty butter, that just deftly
underscores the richness of the flavors, already there.

## What?

DWN is tooling to:

- generate a repo.edn file with checksums of maven artifacts, that can
  be committed to SCM
  - this contains the whole graph of muliple version per coordinate,
    discovered by the dependency crawler in deps.aether
- use a custom, most-recent wins strategy, to always select newer
  versions from repo.edn, in order to build a classpath
  - in addition to most-recent-wins, this retains a partial ordering
    on the classpath, where a referrer would usually be able to
    override its dependents' resource paths (except when they are on
    the wrong side of a dependency cycle)
- generate runners for your clojure code
  - shell launchers
  - systemd .service files
  - edn descriptors, that can be started in webnf.dwn container within
    an existing java process
- compile namespaces to jvm byte code, before building the classpath
- switch between dev mode, where generated artifacts would point into
  a working direcory vs. {dev false}, where everything is
  content-hashed into /nix/store.

## Could?

- DWN could be folded into a bin/dwn script + a .local/share/dwn state
  directory The script could mimic a more traditional
  dependency+build+distribution - tool, by tying together the existing
  functionality and thus be more readily accessible to UNIX users,
  while still providing the benefit of stable builds and a vast
  "standard library" for clojure.java.shell
