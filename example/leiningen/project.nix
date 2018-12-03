{ fromLein, defaultMavenRepos }:
fromLein ./project.clj {
  devMode = false;
  closureRepo = ./project.repo.edn;
  mavenRepos = defaultMavenRepos ++ [ https://maven.repository.redhat.com/ga/ ];
}
