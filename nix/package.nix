{
  crane,
  fenix,
  ...
}:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    let
      toolchain = fenix.packages.${system}.stable.withComponents [
        "cargo"
        "rustc"
        "rust-std"
        "rustfmt"
      ];
      craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;
      root = ../.;

      args = {
        src = lib.fileset.toSource {
          inherit root;
          fileset = lib.fileset.unions [
            (craneLib.fileset.commonCargoSources root)
            (lib.fileset.fileFilter (file: file.hasExt "plist") root)
            ../rift.default.toml
          ];
        };
        strictDeps = true;
        cargoExtraArgs = "--locked --package rift-wm --bin rift --bin rift-cli";
        doCheck = false;

        nativeBuildInputs = [ ];
        buildInputs = [ ];
      };

      cargoArtifacts = craneLib.buildDepsOnly args;

      build = craneLib.buildPackage (
        args
        // {
          inherit cargoArtifacts;
          postInstall = ''
            install -Dm644 rift.default.toml $out/share/rift/rift.default.toml
          '';
          meta = {
            description = "A tiling and scrolling window manager for macOS";
            homepage = "https://github.com/acsandmann/rift";
            license = lib.licenses.asl20;
            platforms = [
              "aarch64-darwin"
            ];
            mainProgram = "rift";
          };
        }
      );

      rift-bin = pkgs.stdenv.mkDerivation {
        pname = "rift-bin";
        version = "0.6.4";
        src = builtins.fetchTarball {
          url = "https://github.com/acsandmann/rift/releases/download/v0.6.4/rift-universal-macos-0.6.4.tar.gz";
          sha256 = "0sxmc757xrni2h92vx4w9cnhkbnlvzk8hxajbllkf8q2xqvnmyxj";
        };
        phases = [ "installPhase" ];
        nativeBuildInputs = [ pkgs.darwin.cctools ];
        installPhase = ''
          mkdir -p $out/bin
          # The upstream universal binary mixes an unsigned Intel slice with a
          # signed ARM slice. TCC can record a requirement that then fails for
          # the running ARM process. Install only our supported architecture.
          for executable in rift rift-cli; do
            lipo "$src/$executable" -thin arm64 -output "$out/bin/$executable"
            chmod 755 "$out/bin/$executable"
          done
          install -Dm644 $src/rift.default.toml $out/share/rift/rift.default.toml
        '';
        meta = {
          description = "Upstream Apple Silicon macOS binaries for Rift";
          homepage = "https://github.com/acsandmann/rift";
          license = lib.licenses.asl20;
          platforms = [ "aarch64-darwin" ];
          mainProgram = "rift";
        };
      };
    in
    {
      checks.rift = build;
      checks.rift-tests = craneLib.cargoTest (
        args
        // {
          inherit cargoArtifacts;
          doCheck = true;
          cargoExtraArgs = "--locked --workspace";
        }
      );

      packages.rift = build;
      packages.rift-bin = rift-bin;
      packages.default = build;

      devshells.default = {
        packages = [
          toolchain
        ];
        commands = [
          {
            help = "";
            name = "hot";
            command = ''${pkgs.watchexec}/bin/watchexec -e rs,toml,lock,plist -w src -w crates -w assets -w build.rs -w Cargo.toml -w Cargo.lock -w rift.default.toml -r -- ${toolchain}/bin/cargo run --package rift-wm --bin rift -- "$@"'';
          }
        ];
      };
    };
}
