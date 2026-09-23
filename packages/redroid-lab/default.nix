{ pkgs }:
let
  src = ./.;
  mk =
    pname: subPackage: extraLdflags:
    pkgs.buildGoModule {
      inherit pname src;
      version = "0.1.0";
      vendorHash = null;
      subPackages = [ subPackage ];
      env.CGO_ENABLED = "0";
      ldflags = [
        "-s"
        "-w"
      ]
      ++ extraLdflags;
      meta.platforms = pkgs.lib.platforms.linux;
    };
  redroidCtl = mk "redroidctl" "./cmd/redroidctl" [ ];
  redroidControl = mk "redroid-control" "./cmd/redroid-control" [ ];
  redroidGateway = mk "redroid-gateway" "./cmd/redroid-gateway" [
    "-X=ghostship.local/redroid-lab/internal/gateway.adbPath=${pkgs.android-tools}/bin/adb"
  ];
  redroidGatewayImage = pkgs.dockerTools.buildLayeredImage {
    name = "redroid-gateway";
    tag = "latest";
    contents = [
      redroidGateway
      pkgs.android-tools
      pkgs.cacert
    ];
    config = {
      Entrypoint = [ "${redroidGateway}/bin/redroid-gateway" ];
      ExposedPorts = {
        "8787/tcp" = { };
      };
      User = "925:925";
    };
  };
in
{
  inherit
    redroidCtl
    redroidControl
    redroidGateway
    redroidGatewayImage
    ;
}
