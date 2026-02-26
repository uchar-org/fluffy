{
  description =
    "A beginning of an awesome project bootstrapped with github:bleur-org/templates";

  inputs = {
    # Stable for keeping thins clean
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # Fresh and new for testing
    nixpkgs.url = "github:xinux-org/upstream";

    # The flake-parts library
    flake-parts.url = "github:hercules-ci/flake-parts";

    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };

  };

  outputs = { self, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } ({ ... }: {
      systems =
        [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { pkgs, system, ... }: {
        _module.args.pkgs = import self.inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
          config.android_sdk.accept_license = true;
          config.permittedInsecurePackages = [ "olm-3.2.16" ];
        };

        # Nix script formatter
        formatter = pkgs.alejandra;

        # Development environment
        devShells.default =
          import ./nix/shell.nix self { inherit pkgs inputs; };

        # Output package
        packages = {
          default = pkgs.callPackage ./nix { };
          web = pkgs.callPackage ./nix { targetFlutterPlatform = "web"; };
        };
      };
    });
}
