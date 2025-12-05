{
  pkgs,
  formatter,
  pinnedFlutter,
  androidCustomPackage,
  pinnedJDK,
  ...
} @ attrs:
pkgs.mkShellNoCC {
  packages = [
    pkgs.rustup
    formatter
    pinnedFlutter
    androidCustomPackage
    pinnedJDK
    pkgs.cocoapods

    (import ./shell_vodozemac.nix attrs)

    (
      pkgs.writeScriptBin "android-emulator" ''
        ${attrs.androidEmulator}/bin/run-test-emulator
      ''
    )
    (
      pkgs.writeScriptBin "android-emulator-no-gpu" ''
        ${attrs.androidEmulatorNoGPU}/bin/run-test-emulator
      ''
    )
  ];

  env = {
    CMAKE_PREFIX_PATH = pkgs.lib.makeLibraryPath [
      pkgs.libsecret.dev
    ];
    ANDROID_HOME = "${androidCustomPackage}/share/android-sdk";
    ANDROID_SDK_ROOT = "${androidCustomPackage}/share/android-sdk";
    JAVA_HOME = pinnedJDK.home;
    FLUTTER_ROOT = "${pinnedFlutter}";
    CHROME_EXECUTABLE = "${pkgs.google-chrome}/bin/google-chrome-stable";
    GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidCustomPackage}/share/android-sdk/build-tools/35.0.0/aapt2";
  };

  shellHook = ''
    init-vodozemac

    echo "---------------------------------------------------------------------------------------------------"
    echo "in order to run android emulator, execute 'android-emulator' and 'android-emulator-no-gpu' commands"
    echo "---------------------------------------------------------------------------------------------------"
  '';
}
