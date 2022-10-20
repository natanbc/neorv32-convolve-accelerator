{ pkgs ? import <nixpkgs> {} }:
let
    python = pkgs.python310.withPackages (python-packages: with python-packages; [
        imageio
        numpy
        scipy
    ]);

    unstable = import (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/master) {};
in
pkgs.mkShell {
    nativeBuildInputs = [
        unstable.ghdl
        gnumake
        python
        unstable.yosys
    ];

    shellHook = ''
        export GHDL_PLUGIN=${unstable.yosys-ghdl}/share/yosys/plugins/ghdl.so
    '';
}

