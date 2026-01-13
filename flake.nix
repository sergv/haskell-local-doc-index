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
              patches = (old.patches or []) ++ [
                ./patches/xmlstarlet-huge.diff
              ];
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
          ] ++ map (x: if builtins.hasAttr "dev" x then x.dev else x) nativeDeps;

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath nativeDeps;
          GHC_DOCS_ROOT = "${ghc.doc}/share/doc/ghc-native-bignum/html/libraries";

          # ... - everything mkDerivation has
        };
      });
}
