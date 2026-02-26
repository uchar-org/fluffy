{
  pkgs,
  callPackage,
  flutter338,
  vodozemac ? callPackage ./vodozemac-wasm.nix {}, 
  ...
}:
pkgs.writeScriptBin "init-vodozemac" ''
  find ./assets/vodozemac ! -name '.gitignore' -type f -exec rm -f {} +
  cp -r ${vodozemac}/* ./assets/vodozemac/
''
