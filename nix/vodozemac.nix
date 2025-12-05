{
  pkgs,
  pubspecLockData,
  ...
}: let
  pubSources = pubspecLockData.pubspecLock.dependencySources;

  # wasm-pack doesn't take 'RUST_SRC_PATH' into consideration
  rustcWithLibSrc = pkgs.buildPackages.rustc.override {
    sysroot = pkgs.symlinkJoin {
      name = "rustc_unwrapped_with_libsrc";
      paths = [
        pkgs.buildPackages.rustc.unwrapped
      ];
      postBuild = ''
        mkdir -p $out/lib/rustlib/src/rust
        ln -s ${pkgs.rustPlatform.rustLibSrc} $out/lib/rustlib/src/rust/library
      '';
    };
  };
in
  # https://github.com/krille-chan/fluffychat/blob/main/scripts/prepare-web.sh
  pkgs.stdenv.mkDerivation {
    pname = "vodozemac-wasm";
    inherit (pubSources.vodozemac) version;

    # These two were in the same repository, so just reuse them
    unpackPhase = ''
      runHook preUnpack

      cp -r ${pubSources.flutter_vodozemac}/rust ./rust
      cp -r ${pubSources.vodozemac} ./dart
      chmod -R +rwx .

      runHook postUnpack
    '';

    # Remove dev_dependencies to avoid downloading them
    postPatch = ''
      sed -i '/^dev_dependencies:/,/^$/d' dart/pubspec.yaml
    '';

    cargoRoot = "rust";

    cargoDeps = pkgs.symlinkJoin {
      name = "vodozemac-wasm-cargodeps";
      paths = [
        pubSources.flutter_vodozemac.passthru.cargoDeps
        # Pull in rust vendor so we don't have to vendor rustLibSrc again
        # This is required because `-Z build-std=std,panic_abort` rebuilds std
        pkgs.rustPlatform.rustVendorSrc
      ];
    };

    nativeBuildInputs = with pkgs; [
      rustPlatform.cargoSetupHook
      rustcWithLibSrc
      rustc.llvmPackages.lld
      cargo
      flutter
      flutter_rust_bridge_codegen
      which
      wasm-pack
      wasm-bindgen-cli_0_2_100
      binaryen
      writableTmpDirAsHomeHook
    ];

    buildPhase = ''
      runHook preBuild

      # Build a pub cache from fluffychat, as dart-vodozemac should be a subset
      # This is required because dart-vodozemac, as a pub, doesn't have a pubspec.lock
      # But flutter_rust_bridge_codegen still requires all dependencies of it
      mkdir -p $NIX_BUILD_TOP/.pub-cache/hosted/pub.dev
      pushd $NIX_BUILD_TOP/.pub-cache/hosted/pub.dev
        ${pkgs.lib.concatMapAttrsStringSep "; " (
          _: p: "ln -s ${p} ./${
            if pkgs.lib.hasPrefix "pub-" p.name
            then pkgs.lib.removePrefix "pub-" p.name
            else p.name
          }"
        )
        pubSources}
      popd

      export PUB_CACHE="$NIX_BUILD_TOP/.pub-cache"

      pushd dart
        dart pub get --offline
      popd
      RUST_LOG=info flutter_rust_bridge_codegen build-web \
        --dart-root $(realpath ./dart) --rust-root $(realpath ./rust) --release

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r dart/web/pkg/vodozemac_bindings_dart* $out/

      runHook postInstall
    '';

    env = {
      RUSTC_BOOTSTRAP = 1; # `-Z build-std=std,panic_abort` requires nightly toolchain
    };
  }
