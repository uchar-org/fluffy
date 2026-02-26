# flake: {pkgs, ...}: let
#   # Hostplatform system
#   system = pkgs.hostPlatform.system;

#   # Production package
#   # base = flake.packages.${system}.default;
# in
#   pkgs.mkShell {
#     # inputsFrom = [base];

#     packages = with pkgs; [
#       nixd
#       statix
#       deadnix
#       alejandra
#     ];
#   }

flake:
{ pkgs, inputs, ... }@attrs:
let
  # Hostplatform system

  system = pkgs.hostPlatform.system;
  formatter = pkgs.alejandra;

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
in pkgs.mkShell {
  packages = [
    pkgs.rustup
    formatter
    pinnedFlutter
    androidCustomPackage
    pinnedJDK

    # (pkgs.callPackage ./shell_vodozemac.nix {})

    (pkgs.writeScriptBin "android-emulator" ''
      ${androidEmulator}/bin/run-test-emulator
    '')
    (pkgs.writeScriptBin "android-emulator-no-gpu" ''
      ${androidEmulatorNoGPU}/bin/run-test-emulator
    '')
  ];

  env = {
    CMAKE_PREFIX_PATH = pkgs.lib.makeLibraryPath [ pkgs.libsecret.dev ];
    ANDROID_HOME = "${androidCustomPackage}/share/android-sdk";
    ANDROID_SDK_ROOT = "${androidCustomPackage}/share/android-sdk";
    JAVA_HOME = pinnedJDK.home;
    FLUTTER_ROOT = "${pinnedFlutter}";
    CHROME_EXECUTABLE = "${pkgs.google-chrome}/bin/google-chrome-stable";
    GRADLE_OPTS =
      "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidCustomPackage}/share/android-sdk/build-tools/35.0.0/aapt2";
  };

  shellHook = ''
    # init-vodozemac

    echo "---------------------------------------------------------------------------------------------------"
    echo "in order to run android emulator, execute 'android-emulator' and 'android-emulator-no-gpu' commands"
    echo "---------------------------------------------------------------------------------------------------"
  '';
}
