{
  description = "fluffychat nix";

  # Flake inputs
  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # 0 Stable Nixpkgs (use 0.1 for unstable)
  inputs.android-nixpkgs = {
    url = "github:tadfisher/android-nixpkgs";
    inputs = {
      nixpkgs.follows = "nixpkgs";
    };
  };

  # Flake outputs
  outputs = inputs: let
    linuxSystems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    darwinSystems = [
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    supportedSystems = linuxSystems ++ darwinSystems;

    eachSystems = systems: f:
      inputs.nixpkgs.lib.genAttrs systems (
        system:
          f {
            inherit system;
            attrs = import ./nix/attrs.nix {inherit system inputs;};
          }
      );

    package = args: target: import ./nix/package.nix args.attrs target;
  in {
    packages = eachSystems supportedSystems (args: {
      linux = package args "linux";
      web = package args "web";
    });
    devShells =
      eachSystems linuxSystems (args: {
        default = import ./nix/shell_linux.nix args.attrs;
      })
      // (
        eachSystems darwinSystems (args: {
          default = import ./nix/shell_darwin.nix args.attrs;
        })
      );
  };
}
