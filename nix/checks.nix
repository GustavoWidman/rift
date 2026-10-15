{ self, nix-darwin, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      lib,
      ...
    }:
    let
      eval =
        settings:
        (nix-darwin.lib.darwinSystem {
          modules = [
            self.darwinModules.default
            {
              nixpkgs.hostPlatform = system;
              system.stateVersion = 6;
              services.rift = {
                enable = true;
              }
              // settings;
            }
          ];
        }).config;
      defaults = eval { };
      disabled = eval { enable = false; };
      withoutConfig = eval { config = null; };
      pathConfig = eval { config = "/tmp/rift config's.toml"; };
      fileConfig = eval { config = ../rift.default.toml; };
      tableConfig = eval { config.settings.animate = false; };
      binaryConfig = eval { package = self.packages.${system}.rift-bin; };
      arguments = config: config.launchd.user.agents.rift.serviceConfig.ProgramArguments;
      overlayPkgs = import self.inputs.nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
    in
    {
      checks.rift-bin-architecture =
        pkgs.runCommand "rift-bin-architecture-check" { nativeBuildInputs = [ pkgs.darwin.cctools ]; }
          ''
            for executable in rift rift-cli; do
              test "$(lipo -archs ${self.packages.${system}.rift-bin}/bin/$executable)" = arm64
              ${self.packages.${system}.rift-bin}/bin/$executable --version
            done
            touch "$out"
          '';
      checks.darwin-module =
        assert !(disabled.launchd.user.agents ? rift);
        assert
          arguments defaults == [
            "${self.packages.${system}.default}/bin/rift"
            "--config"
            "${self.packages.${system}.default}/share/rift/rift.default.toml"
          ];
        assert arguments withoutConfig == [ "${self.packages.${system}.default}/bin/rift" ];
        assert builtins.elemAt (arguments pathConfig) 2 == "/tmp/rift config's.toml";
        assert builtins.hasContext (builtins.elemAt (arguments fileConfig) 2);
        assert
          builtins.elemAt (arguments binaryConfig) 2
          == "${self.packages.${system}.rift-bin}/share/rift/rift.default.toml";
        assert builtins.elem self.packages.${system}.default defaults.environment.systemPackages;
        assert overlayPkgs.rift.drvPath == self.packages.${system}.rift.drvPath;
        assert overlayPkgs.rift-bin.drvPath == self.packages.${system}.rift-bin.drvPath;
        pkgs.runCommand "rift-darwin-module-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          python3 - <<'PY'
          import plistlib, tomllib
          with open('${builtins.elemAt (arguments tableConfig) 2}', 'rb') as f:
              assert tomllib.load(f)['settings']['animate'] is False
          with open('${
            pkgs.writeText "rift.plist" defaults.environment.userLaunchAgents."org.nixos.rift.plist".text
          }', 'rb') as f:
              plist = plistlib.load(f)
          assert plist['ProgramArguments'] == ['${self.packages.${system}.default}/bin/rift', '--config', '${
            self.packages.${system}.default
          }/share/rift/rift.default.toml']
          assert plist['RunAtLoad'] is True
          assert plist['LimitLoadToSessionType'] == 'Aqua'
          with open('${
            pkgs.writeText "rift-file-config.plist" fileConfig.environment.userLaunchAgents."org.nixos.rift.plist".text
          }', 'rb') as f:
              file_plist = plistlib.load(f)
          with open(file_plist['ProgramArguments'][2], 'rb') as f:
              assert 'settings' in tomllib.load(f)
          PY
          touch "$out"
        '';
    };
}
