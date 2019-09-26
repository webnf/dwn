with import ./shell.nix;

let
  art = mvn: build { inherit mvn; };
in

rec {

  depA0 = art {
    artifact = "A";
    version = "0";
    dependencies = [
      depB1 depC0
    ];
  };

  depB0 = art {
    artifact = "B";
    version = "0";
  };

  depB1 = art {
    artifact = "B";
    version = "1";
  };

  depC0 = art {
    artifact = "C";
    version = "0";
    dependencies = [
      depB0
    ];
  };
  
}
