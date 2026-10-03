# Nix integration

The flake supports Apple Silicon macOS. `packages.default` and
`packages.rift` build the checked-out source, including `rift` and `rift-cli`.
`packages.rift-bin` extracts the ARM64 binaries from the pinned upstream 0.6.4 universal release.
The unsigned Intel slice is omitted so macOS can use the ARM code signature
consistently for Accessibility permissions.
Both packages include their matching default configuration under
`share/rift/rift.default.toml`.

```sh
nix build .#rift
./result/bin/rift --version
./result/bin/rift-cli --version
nix build .#rift-bin
nix develop
nix flake check
```

The `hot` development command reruns Cargo when Rust sources change.

## nix-darwin

Add this fork as an input and import `rift.darwinModules.default`:

```nix
{
  inputs.rift.url = "github:gustavowidman/rift/<your-published-ref>";

  outputs = { nix-darwin, rift, ... }: {
    darwinConfigurations.myMac = nix-darwin.lib.darwinSystem {
      modules = [
        rift.darwinModules.default
        {
          services.rift.enable = true;
          # Optional: use the upstream release instead of compiling source.
          # services.rift.package = rift.packages.aarch64-darwin.rift-bin;
        }
      ];
    };
  };
}
```

The module installs both executables and creates the per-user launchd agent
`org.nixos.rift`. Its default config comes from the selected package.
`services.rift.config` also accepts a TOML attribute set, a file path, or `null`
to use Rift's normal config discovery. File paths are passed as a single
launchd argument, including paths containing spaces or quotes. Configurations in
the Nix store are read-only; use `config = null` to let Rift manage a writable
configuration in its normal location.

```nix
services.rift.config = {
  settings.animate = true;
  settings.focus_follows_mouse = false;
};
```

The overlay exposes `pkgs.rift` and `pkgs.rift-bin`:

```nix
nixpkgs.overlays = [ rift.overlays.default ];
```

Grant the selected Rift executable Accessibility permission in System Settings
before expecting the agent to manage windows. macOS may require granting it
again when a rebuild changes the executable's store path. Screen Recording is
used for optional Overview previews. Stop other window managers before enabling
Rift. The module owns the launchd agent; use nix-darwin to manage it instead of
also running `rift service install`.

The flake tracks nixpkgs unstable and nix-darwin master. Fenix supplies the
stable Rust toolchain. Intel Darwin is not an advertised target.

## Checks

`nix flake check` builds the source package, runs upstream workspace tests, and
checks a nix-darwin evaluation and its generated plist. Module checks cover
disabled services, package installation, default/binary config selection,
`null`, TOML generation, quoted file paths, and the overlay.

These checks do not activate nix-darwin or grant macOS permissions. Interactive
window management requires a separate runtime check on a Mac with Accessibility
permission.
