{ pkgs ?
  import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/c0e56afddbcf6002e87a5ab0e8e17f381e3aa9bd.tar.gz";
    sha256 = "1zg28j760qgjncqrf4wyb7ijzhnz0ljyvhvv87m578c7s84i851l";
  }) {}
}:

with pkgs;

stdenv.mkDerivation rec {
  name = "genspio";
  src = null;
  buildInputs = with ocamlPackages;
  [
    ocaml
    findlib
    dune
  ];

  shellHook = "export OCAMLFORMAT_LOCATION=${ocamlformat}";
}
