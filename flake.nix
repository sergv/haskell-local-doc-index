{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
          t    = pkgs.lib.trivial;
          hl   = pkgs.haskell.lib;

          hpkgs = pkgs.haskell.packages.ghc9101;

          ghc = hpkgs.ghc.override {
            enableDocs = true;
            # enableHaddockProgram = true;
          };

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

          nativeDeps = [
            pkgs.curl.dev
            pkgs.expat
            pkgs.fontconfig
            pkgs.freetype
            pkgs.gd
            pkgs.glib
            pkgs.harfbuzz
            pkgs.libdeflate
            pkgs.libGLU
            pkgs.libjpeg
            pkgs.libpng
            pkgs.libtiff
            pkgs.libwebp
            pkgs.lzma
            pkgs.pcre2
            pkgs.SDL2
            pkgs.SDL2_gfx
            pkgs.SDL2_image
            pkgs.SDL2_mixer
            pkgs.SDL2_net
            pkgs.SDL2_sound
            pkgs.SDL2_ttf
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
          ] ++ map (x: if builtins.hasAttr "dev" x then x.dev else x) nativeDeps;

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath nativeDeps;
          GHC_DOCS_ROOT = "${ghc.doc}/share/doc/ghc/html/libraries";

          # ... - everything mkDerivation has
        };
      });
}
