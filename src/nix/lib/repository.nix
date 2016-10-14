let
  versionedDep = id: version: hash:
    builtins.listToAttrs [{name=id; value={
        "DEFAULT" = [ "alias" version ];
      } // builtins.listToAttrs [{name=version; value=["mvn" hash];}];
    }];
  logbackDep = id: hash: versionedDep id "1.1.7" hash;
  slf4jDep = id: hash: versionedDep id "1.7.21" hash;
in {
"org.clojure" = {
  "clojure" = {
    "DEFAULT" = [ "alias" "1.9.0-alpha13" ];
    "1.9.0-alpha13" = [ "mvn" "05d4r5gjbf0hx43v7174ndz2zsv1xdl9gh3kkw1z08dw4gliljck" ];
    "1.8.0" = [ "mvn" "1a30sdpn1rr50w7qfz6pn3z5i43fjq3z9qm1aa4cd9piwhgpy6h6" ];
  };
} // (
  (versionedDep "tools.logging" "0.3.1" "0727j7861m2b8z7d55a863d8mnlb28cz6850rv2s2cvs95fv4mzx")
//(versionedDep "tools.nrepl" "0.2.12" "0s9bfxf0w0cv09284w8l1dqcxyiqvl7p0kr9xmv8q6h3fmxs2gg2")
);
"webnf" = {
  "dwn" = {
    "DEFAULT" = [ "nix" ../../../artefact.nix ];
  };
};
"webnf.dwn" = {
  "nrepl" = {
    "DEFAULT" = [ "nix" ../../../nrepl-cmp.nix ];
  };
};
"ch.qos.logback" = (
  (logbackDep "logback-classic" "1nbp2sipswppp2013a7rmk9m8cihrf42bc28nxxwry6vcf993hx2")
//(logbackDep "logback-core" "1ppinajcr35lca4gjy0q1vp36qmv828mg636w184iyl14vgsw055")
);

"org.slf4j" = (
  (slf4jDep "slf4j-api" "1pz7yf553zp7v1l1w3zaj6knhr2zq10yksk928axs3wbv5mynnhx")
//(slf4jDep "log4j-over-slf4j" "1jzzibcqb9329p076y75m7vdanlvr10w5mx41kvsb5nz3yv63if8")
//(slf4jDep "jcl-over-slf4j" "0gsypqkhkrxmjgl9j1jhx67divb7vkfg7fwvjrdncyvv6nmrssv8")
//(slf4jDep "jul-to-slf4j" "1g78j4fb9d7fgnl6fjjgcw47xb81wwqwd03s4iw8mcssb6nnsva4")
);
"javax.servlet" = (
  (versionedDep "javax.servlet-api" "3.1.0" "10l47crybiq5z9qk0kdx6pzdjww9cyy47rzkak7q4khwshnnnidg")
);
"javax.mail" = (
  (versionedDep "javax.mail-api" "1.5.5" "2a30sdpn1rr50w7qfz6pn3z5i43fjq3z9qm1aa4cd9piwhgpy6h6")
);
"com.sun.mail" = (
  (versionedDep "javax.mail" "1.5.5" "2a30sdpn1rr50w7qfz6pn3z5i43fjq3z9qm1aa4cd9piwhgpy6h6")
);
"com.stuartsierra" = (
  (versionedDep "component" "0.3.1" "06i7dxyl573k0l4f677nq2y96a5yv8jhwzm9ccwbxmh73xc4azcq")
//(versionedDep "dependency" "0.2.0" "1krbb80jqk7cgszakn3kx0gk1vlzy5a7n6kyva8r42apydjis8s1")
);
"refactor-nrepl" = (
  (versionedDep "refactor-nrepl" "2.2.0" "1sd6mihm559qsx62r6jqsmnfsf33gq86vhdigazr8rjjgckxmjnv")
);
"cider" = (
  (versionedDep "cider-nrepl" "0.14.0" "0x8rc4wrm11fhham5833f89a428xmahxbgivglgxf45nlyx63sbq")
);
"org.tcrawley" = (
  (versionedDep "dynapath" "0.2.3" "1pxaxr5bghbi358l5bfirm5arn0jzhpbip9l6kgs08f84h8lvl06")
);
}
