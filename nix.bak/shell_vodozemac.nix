{
  pkgs,
  vodozemac,
  ...
}:
pkgs.writeScriptBin "init-vodozemac" ''
  find ./assets/vodozemac ! -name '.gitignore' -type f -exec rm -f {} +
  cp -r ${vodozemac}/* ./assets/vodozemac/
''
