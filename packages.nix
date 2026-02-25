{
  pkgs,
  lib,
  crate2nix,
  makeWrapper,
  nix,
  nix-src,
}:
let
  cargoNix = import "${crate2nix}/lib/build-from-json.nix" {
    inherit pkgs;
    src = lib.cleanSourceWith {
      src = ./.;
      filter =
        path: type:
        (lib.hasSuffix ".toml" path)
        || (lib.hasSuffix ".lock" path)
        || (lib.hasSuffix ".rs" path)
        || (lib.hasInfix "/harmonia-" path)
        || (lib.hasSuffix ".pk" path)
        || (lib.hasSuffix ".sk" path)
        || (lib.hasSuffix ".pem" path)
        || (type == "directory");
    };
    resolvedJson = ./Cargo.json;
  };

  # The main binary crate
  harmonia = pkgs.runCommand "harmonia-${version}" {
    nativeBuildInputs = [ makeWrapper ];
    meta = with lib; {
      description = "Nix binary cache implemented in rust";
      homepage = "https://github.com/nix-community/harmonia";
      license = with licenses; [ mit ];
      maintainers = [ maintainers.mic92 ];
      platforms = platforms.all;
    };
  } ''
    mkdir -p $out/bin
    # harmonia-client produces the "harmonia" binary
    cp ${cargoNix.workspaceMembers.harmonia-client.build}/bin/harmonia $out/bin/
    # harmonia-cache produces the "harmonia-cache" binary
    cp ${cargoNix.workspaceMembers.harmonia-cache.build}/bin/harmonia-cache $out/bin/
    # harmonia-daemon
    cp ${cargoNix.workspaceMembers.harmonia-daemon.build}/bin/harmonia-daemon $out/bin/
    wrapProgram $out/bin/harmonia \
      --prefix PATH : ${lib.makeBinPath [ nix ]}
  '';

  version = (lib.importTOML ./Cargo.toml).workspace.package.version;
in
{
  inherit harmonia;
  default = harmonia;
}
