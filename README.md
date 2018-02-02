DWN -- A Clojure launcher via Nix(OS)
=====================================

## Installation

### Nix

For now, you need the [Nix package manager](https://nixos.org/nix/)
installed. This is most easily done by

```sh
curl https://nixos.org/nix/install | sh
```

### Installing from checkout

There is rudimentary command line tooling, in the form of a `dwn`
command. You can build it with:

```sh
nix-build shell.nix -A dwnTool
```

Install it to your user profile with:
```sh
nix-env -i ./result
```

Now, the `dwn` command should be in your `$PATH`.


## Usage

You need a `project.nix` file. Most easily, this can be written by delegating to a Leiningen Project:

```nix
{ fromLein, devMode ? false }:
fromLein ./project.clj {
  inherit devMode;
  repo = ./project.repo.edn;
}
```

With the `project.nix` file in place, you need to generate a
repository file for the project. That file holds all the `sha1`s for
you dependency artifacts, similar to a `php-composer` lockfile. This
command generates the repo file in `project.repo.edn`, which is meant
to be checked in:
```sh
dwn gen-repo ./project.nix
```

After having generated the repo file, you can build the project:
```sh
dwn build ./project.nix
```

This generates `./result` with a classpath for your project, along
with shell launchers for your main namespaces.

# Dev Notes

The entry path is `shell.nix -> default.nix -> packages.nix`

There is some interesting bootstrapping going on between
`deps.aether/default.nix` and `deps.expander/default.nix`, but
`project.nix` is already a fully formed project descriptor for the
`webnf.dwn` runtime library.

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
opinionated. Instead, it's just plain butter, that
underscores the the flavors, already there.

## What?

DWN is tooling to:

- generate a project.repo.edn file with checksums of maven artifacts,
  that can be committed to SCM
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
  - systemd .service files (to be exposed via `dwn`)
  - edn descriptors, that can be started in webnf.dwn container within
    an existing java process (to be exposed via `dwn`)
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
