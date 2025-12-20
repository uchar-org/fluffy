{
  pkgs,
  pinnedFlutter,
  libwebrtcRpath,
  libwebrtc,
  vodozemac,
  packageAttrs,
  androidCustomPackage,
  pinnedJDK,
  ...
}: targetFlutterPlatform:
pinnedFlutter.buildFlutterApplication (
  packageAttrs
  // rec {
    pname = "berk-${targetFlutterPlatform}";

    src = ../.;

    inherit targetFlutterPlatform;

    meta =
      {
        description = "Chat with your friends (matrix client)";
        homepage = "https://uzberk.uz/";
        license = pkgs.lib.licenses.agpl3Plus;
        maintainers = with pkgs.lib.maintainers; [
          mkg20001
          tebriel
          aleksana
        ];
        badPlatforms = pkgs.lib.platforms.darwin;
      }
      // pkgs.lib.optionalAttrs (targetFlutterPlatform == "linux") {
        mainProgram = "berk";
      };
  }
  // pkgs.lib.optionalAttrs (targetFlutterPlatform == "linux") {
    nativeBuildInputs = [
      pkgs.imagemagick
      pkgs.copyDesktopItems
    ];

    runtimeDependencies = [pkgs.pulseaudio];

    env.NIX_LDFLAGS = "-rpath-link ${libwebrtcRpath}";

    desktopItems = [
      (pkgs.makeDesktopItem {
        name = "Berk";
        exec = "berk";
        icon = "berk";
        desktopName = "Berk";
        genericName = "Chat with your friends (matrix client)";
        categories = [
          "Chat"
          "Network"
          "InstantMessaging"
        ];
      })
    ];

    customSourceBuilders = {
      flutter_webrtc = {
        version,
        src,
        ...
      }:
        pkgs.stdenv.mkDerivation {
          pname = "flutter_webrtc";
          inherit version src;
          inherit (src) passthru;

          postPatch = ''
            substituteInPlace third_party/CMakeLists.txt \
              --replace-fail "\''${CMAKE_CURRENT_LIST_DIR}/downloads/libwebrtc.zip" ${libwebrtc}
              ln -s ${libwebrtc} third_party/libwebrtc
          '';

          installPhase = ''
            runHook preInstall

            mkdir $out
            cp -r ./* $out/

            runHook postInstall
          '';
        };
    };

    postInstall = ''
      FAV=$out/app/berk-linux/data/flutter_assets/assets/favicon.png
      ICO=$out/share/icons

      for size in 24 32 42 64 128 256 512; do
        D=$ICO/hicolor/''${size}x''${size}/apps
        mkdir -p $D
        magick $FAV -resize ''${size}x''${size} $D/fluffychat.png
      done

      patchelf --add-rpath ${libwebrtcRpath} $out/app/berk-linux/lib/libwebrtc.so
    '';
  }
  // pkgs.lib.optionalAttrs (targetFlutterPlatform == "web") {
    preBuild = ''
      cp -r ${vodozemac}/* ./assets/vodozemac/
    '';
  }
  // pkgs.lib.optionalAttrs (targetFlutterPlatform == "apk") {
    targetFlutterPlatform = "universal";

    ANDROID_SDK_ROOT = "${androidCustomPackage}/share/android-sdk";
    JAVA_HOME = pinnedJDK;
    FLUTTER_ROOT = "${pinnedFlutter}";
    CHROME_EXECUTABLE = "${pkgs.google-chrome}/bin/google-chrome-stable";
    GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidCustomPackage}/share/android-sdk/build-tools/35.0.0/aapt2";

    nativeBuildInputs = [
      androidCustomPackage
      pinnedJDK
    ];

    buildPhase = ''
      runHook preBuild

      mkdir -p build/flutter_assets/fonts

      flutter build apk -v --split-debug-info="$debug" $flutterBuildFlags

      runHook postBuild
    '';
  }
)
