{
  inputs,
  system,
  ...
}: let
  attrs = rec {
    pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    formatter = pkgs.alejandra;
    # https://github.com/catppuccin/nix/blob/08716214674ca27914daa52e6fa809cc022b581e/modules/lib/default.nix#L99
    importYAML = path:
      pkgs.lib.importJSON (
        pkgs.runCommand "converted.json" {
          pname = "converted.json";
          version = "0.0.1";
          nativeBuildInputs = [pkgs.yj];
        } ''
          yj < ${path} > $out
        ''
      );

    pinnedFlutter = pkgs.flutter335;
    pinnedJDK = pkgs.jdk17_headless;
    androidCustomPackage = inputs.android-nixpkgs.sdk.${system} (
      # show all potential values with
      # nix flake show github:tadfisher/android-nixpkgs
      sdkPkgs:
        with sdkPkgs; [
          cmdline-tools-latest
          cmake-3-22-1
          build-tools-35-0-0
          ndk-27-0-12077973
          # platform-tools
          # emulator
          platforms-android-31
          platforms-android-33
          platforms-android-34
          platforms-android-35
          platforms-android-36
          # system-images-android-36-google-apis-playstore-x86-64
        ]
    );
    libwebrtcRpath = pkgs.lib.makeLibraryPath [
      pkgs.libgbm
      pkgs.libdrm
    ];
    pubspecFile = ../pubspec.yaml;
    pubspec = importYAML pubspecFile;
    pubspecLockFile = ../pubspec.lock;
    pubspecLock = importYAML pubspecLockFile;
    pubspecOnlySource = pkgs.stdenv.mkDerivation {
      name = "fluffychat-pubspec-only-source";
      nativeBuildInputs = [
        pinnedFlutter
      ];
      unpackPhase = ''
        mkdir $out
        cp ${pubspecFile} "$out/pubspec.yaml"
        cp ${pubspecLockFile} "$out/pubspec.lock"
      '';
    };
    pubspecLockData = pinnedFlutter.buildFlutterApplication (
      packageAttrs
      // {
        pname = "fluffychat-pubspec-lock-data";
        src = pubspecOnlySource;
        buildPhase = ''
          runHook preBuild
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p $out
          runHook postInstall
        '';
        targetFlutterPlatform = "web";
      }
    );
    libwebrtc = pkgs.fetchzip {
      url = "https://github.com/flutter-webrtc/flutter-webrtc/releases/download/v1.1.0/libwebrtc.zip";
      sha256 = "sha256-lRfymTSfoNUtR5tSUiAptAvrrTwbB8p+SaYQeOevMzA=";
    };
    packageAttrs = {
      version = pubspec.version;
      inherit pubspecLock;

      gitHashes = {
        flutter_web_auth_2 = "sha256-3aci73SP8eXg6++IQTQoyS+erUUuSiuXymvR32sxHFw=";
        flutter_secure_storage_linux = "sha256-cFNHW7dAaX8BV7arwbn68GgkkBeiAgPfhMOAFSJWlyY=";
      };
    };
    vodozemac = import ./vodozemac.nix attrs;
  };
in
  attrs
