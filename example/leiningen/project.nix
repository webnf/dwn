{ fromLein }:
fromLein ./project.clj {
  devMode = false;
  closureRepo = ./project.repo.edn;
}
