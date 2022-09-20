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

          cabal-repo = pkgs.fetchFromGitHub {
            owner = "sergv";
            repo = "cabal";
            rev = "dev";
            sha256 = "sha256-m0hHnC460ZoB9o/YweRMCG5onqgMrwPfexYzZDriR30="; # pkgs.lib.fakeSha256;
          };

          hpkgs = pkgs.haskell.packages.ghc942;

          hpkgsCabal = pkgs.haskell.packages.ghc924.override {
            overrides = self: super: {
              Cabal = self.callCabal2nix
                "Cabal"
                (cabal-repo + "/Cabal")
                {};
              Cabal-syntax = self.callCabal2nix
                "Cabal-syntax"
                (cabal-repo + "/Cabal-syntax")
                {};
              cabal-install-solver = self.callCabal2nix
                "cabal-install-solver"
                (cabal-repo + "/cabal-install-solver")
                {};
              cabal-install = self.callCabal2nix
                "cabal-install"
                (cabal-repo + "/cabal-install")
                { inherit (self) Cabal-described Cabal-QuickCheck Cabal-tree-diff;
                };
              process = pkgs.haskell.lib.dontCheck
                (self.callHackage "process" "1.6.15.0" {});
            };
          };

          ghc = hpkgs.ghc.override {
            enableDocs = true;
            enableHaddockProgram = true;
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
            pkgs.libGLU
            pkgs.libjpeg
            pkgs.libpng
            pkgs.lzma
            pkgs.SDL2
            pkgs.SDL2_gfx
            pkgs.SDL2_image
            pkgs.SDL2_mixer
            pkgs.SDL2_net
            pkgs.SDL2_sound
            pkgs.SDL2_ttf
            pkgs.zlib
          ];

      in {
        devShell = pkgs.mkShell {

          buildInputs = nativeDeps;

          nativeBuildInputs = [
            pkgs.pkg-config
            ghc
            hpkgsCabal.cabal-install
          ] ++ map (x: if builtins.hasAttr "dev" x then x.dev else x) nativeDeps;

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath nativeDeps;
          GHC_DOCS_ROOT = "${ghc.doc}/share/doc/ghc/html/libraries";

          # ... - everything mkDerivation has
        };
      });
}
