let
  versionedDep = id: version: hash:
    builtins.listToAttrs [{name=id; value={
        "DEFAULT" = [ "alias" version ];
      } // builtins.listToAttrs [{name=version; value=["mvn" hash];}];
    }];
  logbackDep = id: hash: versionedDep id "1.1.3" hash;
  slf4jDep = id: hash: versionedDep id "1.7.13" hash;
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
  (logbackDep "logback-classic" "1map874h9mrv2iq8zn674sb686fdcr2p5k17ygajqr0dbn7z3hwq")
//(logbackDep "logback-core" "052w3z1sp7m2ssrd8c644wxi8xia9crcrjmcixdk3lwm54sgvh27")
);

"org.slf4j" = (
  (slf4jDep "slf4j-api" "0d8fk9jggkhvi1vgaxk0f6wa4jfzd25jp1b4q7zq9fag5q68vmi0")
//(slf4jDep "log4j-over-slf4j" "1pwr1skmgs6vcnr7qx66w4xahyw9lg6894zic3a1xlj2h7hwsj30")
//(slf4jDep "jcl-over-slf4j" "0ijimbf88pvrd37sm7i8i5qg25ni6wccyarpck30i12lpd9y3i3l")
//(slf4jDep "jul-to-slf4j" "11blwm82aa2bp90q5hcfx3qfnigbq5j4h4c2k4s4lgi71n270rgw")
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
  (versionedDep "refactor-nrepl" "2.1.0-alpha1" "1p359rcjb51i3212pv4vvy659jmj0ckxjanmqzg511czwn01h57x")
);
"cider" = (
  (versionedDep "cider-nrepl" "0.13.0" "0icdaybyb1ln4zjxwa7g3x63d4z0p6liac5vfqwjlssg2xazg48x")
);
"org.tcrawley" = (
  (versionedDep "dynapath" "0.2.3" "1pxaxr5bghbi358l5bfirm5arn0jzhpbip9l6kgs08f84h8lvl06")
);
}
