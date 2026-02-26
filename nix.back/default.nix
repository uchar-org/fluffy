{ pkgs, stdenv, flutter338, lib, inputs, targetFlutterPlatform, ... }:

let
  # Hostplatform system

  system = pkgs.hostPlatform.system;
  formatter = pkgs.alejandra;

  vodozemac = import ./vodozemac-wasm.nix;

  androidEmulator = pkgs.androidenv.emulateApp {
    name = "emulator";
    platformVersion = "36";
    abiVersion = "x86_64";
    systemImageType = "google_apis_playstore";
    configOptions = {
      "hw.gpu.enabled" = "yes";
      "hw.gpu.mode" = "swiftshader_indirect";
      "hw.keyboard" = "yes";
      "hw.kainKeys" = "yes";
    };
  };
  androidEmulatorNoGPU = pkgs.androidenv.emulateApp {
    name = "emulator";
    platformVersion = "36";
    abiVersion = "x86_64";
    systemImageType = "google_apis_playstore";
    configOptions = {
      "hw.gpu.enabled" = "yes";
      "hw.keyboard" = "yes";
      "hw.kainKeys" = "yes";
    };
  };

  pinnedFlutter = pkgs.flutter338;
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
      ndk-28-2-13676358
      platform-tools
      emulator
      platforms-android-31
      platforms-android-33
      platforms-android-34
      platforms-android-35
      platforms-android-36
      system-images-android-36-google-apis-playstore-x86-64
    ]);

  # Production package
  # base = flake.packages.${system}.default;

in flutter338.buildFlutterApplication ({
  pname = "uchar-${targetFlutterPlatform}";
  version = "2.4.1";

  src = lib.cleanSource ./..;

  nativeBuildInputs = [
    pkgs.rustup
    formatter
    pinnedFlutter
    androidCustomPackage
    pinnedJDK

    # (pkgs.callPackage ./shell_vodozemac.nix { })

    (pkgs.writeScriptBin "android-emulator" ''
      ${androidEmulator}/bin/run-test-emulator
    '')
    (pkgs.writeScriptBin "android-emulator-no-gpu" ''
      ${androidEmulatorNoGPU}/bin/run-test-emulator
    '')
  ];

  pubspecLock = lib.importJSON ./pubspec.lock.json;

  meta = {
    description = "Chat with your friends (matrix client)";
    homepage = "https://uchar.uz/";
    license = lib.licenses.agpl3Plus;
    maintainers = with lib.maintainers; [ mkg20001 tebriel aleksana ];
    badPlatforms = lib.platforms.darwin;
  };

  # Some dev env bootstrap scripts # yellow = 3; blue = 4
  shellHook = "\n";
}

  // pkgs.lib.optionalAttrs (targetFlutterPlatform == "web") {
    # preBuild = ''
    #   cp -r ${vodozemac}/* ./assets/vodozemac/
    # '';

    buildPhase = ''
      # runHook preBuild
      flutter build web
      # runHook postBuild
    '';

    installPhase = ''
      # runHook preInstall
      mkdir -p $out/build
      cp build/web $out/build -r

      mkdir $debug
      mkdir $pubcache
      # runHook postInstall
    '';
  })
