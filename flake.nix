{
  inputs = {
    nixpkgs = {
      url = "nixpkgs";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    haskell-nixpkgs-improvements = {
      url = "github:sergv/haskell-nixpkgs-improvements" ;
      # url = "/home/sergey/projects/nix/haskell-nixpkgs-improvements";

      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-unstable.follows = "nixpkgs";
    };

  };

  outputs = { self, nixpkgs, flake-utils, haskell-nixpkgs-improvements }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages."${system}";

          # pkgs = import nixpkgs {
          #   inherit system;
          #   config = haskell-nixpkgs-improvements.config.host;
          #   overlays = [
          #     haskell-nixpkgs-improvements.overlays.host
          #   ];
          # };

          # ghcs = haskell-nixpkgs-improvements.lib.create-ghcs system pkgs null;
          #
          # ghc = ghcs.ghc.host.ghc9141.override {
          #   enableDocs = true;
          # };

          packages = haskell-nixpkgs-improvements.packages."${system}";

          hiedb = haskell-nixpkgs-improvements.haskell-package-sets.x86_64-linux.host.ghc914.hiedb;

          ghc = packages.ghc9141.override {
            enableDocs = true;
          };

          # hpkgs = pkgs.haskell.packages.ghc9121;
          #
          # ghc = hpkgs.ghc.override {
          #   enableDocs = true;
          #   # enableHaddockProgram = true;
          # };

          # GTK-enabled deps
          # nativeDeps = [
          #   pkgs.atk
          #   pkgs.curl.dev
          #   pkgs.gd
          #   pkgs.gobject-introspection
          #   pkgs.gtk4
          #   pkgs.libGLU
          #   pkgs.pango
          #   pkgs.pcre
          #   pkgs.SDL2
          #   pkgs.SDL2_gfx
          #   pkgs.SDL2_image
          #   pkgs.SDL2_mixer
          #   pkgs.SDL2_net
          #   pkgs.SDL2_sound
          #   pkgs.SDL2_ttf
          #   pkgs.xorg.libXdmcp
          #   pkgs.zlib
          # ];

          xmlstarlet-pkg =
            (pkgs.xmlstarlet.override (old: {
              libxml2 = old.libxml2.overrideAttrs (old2: {
                patches = (old2.patches or []) ++ [
                  ./patches/0001-Make-XML_PARSE_HUGE-be-able-to-handle-100kb-document.patch
                ];
              });
            })).overrideAttrs (old: {
              src = pkgs.fetchFromGitHub {
                owner  = "random-random-stuff";
                repo   = "xmlstar";
                rev    = "a7228161756b47e1348a6ad97bda10e511cb546a";
                sha256 = "sha256-auz0o0sTaoKPbvaFDYJwt1ZnoyfWcdjyNUc5JV6hkHU="; #pkgs.lib.fakeSha256;
              };
              patches = [
                ./patches/xmlstarlet-huge.diff
                ./patches/xmlstarlet-disable-docs.patch
                (pkgs.fetchurl {
                  name = "libxml-2.14.patch";
                  url  = "https://github.com/termux/termux-packages/raw/39135f3f1190268d127b998c2c6040d9af611ba5/packages/xmlstarlet/libxml2-2.14-attribute-unused.patch";
                  hash = "sha256-zHkUQsrhPLWI3kdfCITbcixpBmDRmxSM2Viz5R+8q5E=";
                })
              ];
              configureFlags =
                (old.configureFlags or []) ++
                ["--disable-build-docs"];
            });

          nativeDeps = [
            xmlstarlet-pkg

            pkgs.curl.dev
            pkgs.expat
            pkgs.fontconfig
            pkgs.freetype
            pkgs.gd
            pkgs.glib
            pkgs.harfbuzz
            pkgs.lerc
            pkgs.libdeflate
            pkgs.libGLU
            pkgs.libjpeg
            pkgs.libpng
            pkgs.libsysprof-capture
            pkgs.libtiff
            pkgs.libwebp
            pkgs.pcre2
            pkgs.SDL2
            pkgs.SDL2_gfx
            pkgs.SDL2_image
            pkgs.SDL2_mixer
            pkgs.SDL2_net
            pkgs.SDL2_sound
            pkgs.SDL2_ttf
            pkgs.xz
            pkgs.zlib

            # For glfw
            pkgs.freeglut
            # This gives us libGL
            pkgs.libglvnd
            # This gives us libGLU
            pkgs.libGLU
            pkgs.xorg.libX11

            pkgs.xorg.libXi
            pkgs.xorg.libXrandr
            pkgs.xorg.libXxf86vm
            pkgs.xorg.libXcursor
            pkgs.xorg.libXinerama
          ];

      in {
        devShell = pkgs.mkShell {

          buildInputs = nativeDeps;

          nativeBuildInputs = [
            pkgs.pkg-config
            ghc
            packages.cabal

            hiedb
          ] ++ map (x: if builtins.hasAttr "dev" x then x.dev else x) nativeDeps;

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath nativeDeps;
          GHC_DOCS_ROOT = "${ghc.doc}/share/doc/ghc-native-bignum/html/libraries";

          # ... - everything mkDerivation has
        };
      });
}
