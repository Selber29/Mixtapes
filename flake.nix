{
  description = "Python development setup with Nix for Mixtapes project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        version = pkgs.lib.pipe (self + "/com.pocoguy.Muse.metainfo.xml") [
          builtins.readFile
          (builtins.match ".*<releases>[^<]*<release version=\"([^\"]+)\"[^>]*>.*")
          builtins.head
        ];

        lines = pkgs.lib.pipe (self + "/requirements.txt") [
          builtins.readFile
          (builtins.split "\n")
          (builtins.filter (x: builtins.isString x && x != ""))
        ];

        pipName = line: let
          m = builtins.match "([a-zA-Z][a-zA-Z0-9._-]*).*" line;
        in
          if m == null then null else builtins.head m;

        pipToNix = {
          PyGObject = "pygobject3";
          Pillow = "pillow";
          StrEnum = "strenum";
        };

        nixAttr = name: pipToNix.${name} or (pkgs.lib.strings.toLower name);

        pythonDeps = pkgs.lib.pipe lines [
          (builtins.map pipName)
          (builtins.filter (n: n != null))
          (builtins.map (name: pkgs.python314Packages.${nixAttr name} or null))
          (builtins.filter (d: d != null))
        ];

        pythonEnv = pkgs.python314.withPackages (ps: pythonDeps);

        mixtapes = pkgs.stdenv.mkDerivation {
          pname = "mixtapes";
          inherit version;
          src = self;

          nativeBuildInputs = [ pkgs.makeWrapper pkgs.wrapGAppsHook3 ];

          buildInputs = [
            pkgs.gtk4
            pkgs.libadwaita
            pkgs.webkitgtk_6_0
            pkgs.gobject-introspection
            pkgs.gst_all_1.gstreamer
            pkgs.gst_all_1.gst-plugins-base
            pkgs.gst_all_1.gst-plugins-good
            pkgs.gst_all_1.gst-plugins-bad
            pkgs.gst_all_1.gst-plugins-ugly
            pythonEnv
          ];

          installPhase = ''
            mkdir -p $out/bin $out/share/mixtapes
            cp -r src/* $out/share/mixtapes/
            makeWrapper ${pythonEnv}/bin/python $out/bin/mixtapes \
              --add-flags "$out/share/mixtapes/main.py"
          '';
        };
      in {
        packages.default = mixtapes;

        devShells.default = pkgs.mkShell {
          inputsFrom = [ mixtapes ];
          packages = [ pkgs.nodejs ];
          shellHook = ''
            python --version
          '';
        };
      }
    );
}
