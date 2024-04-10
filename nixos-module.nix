{
  pkgs,
  lib,
  stdenvNoCC,
  config,
  ...
}:
with lib;
let
  gpkgs = pkgs.callPackage ./default.nix {};
  cfg = config.services.garrys-mod;
  defaultUser = {
    name = "garrys-mod";
    group = "garrys-mod";
    isSystemUser = true;
    createHome = true;
    home = cfg.dataDir;
  };
in {
  options.services.garrys-mod = {
    enable = mkEnableOption "Garry's Mod";
    dataDir = mkOption {
      example = "/var/lib/gmstranded/";
      default = "/var/lib/garrys-mod/";
      type = types.str;
      description = ''
        The directory containing the stateful data of the Garry's Mod server.
        In a typical steamcmd installation, this would be the `garrysmod` folder.
      '';
    };
    address = mkOption {
      example = "127.0.0.1";
      default = null;
      type = with types; nullOr str;
      description = ''
        The address to bind the Garry's Mod server to.
        (NOTE: srcds_run seems to ignore this completely. Check `netstat` when running.)
      '';
    };
    port = mkOption {
      example = 27805;
      default = 27015;
      type = types.port;
      description = ''
        The port to bind the Garry's Mod server to.
      '';
    };
    openFirewall = mkOption {
      default = false;
      type = types.bool;
      description = "Opens the given `port` in the firewall.";
    };
    gamemode = mkOption {
      example = "terrortown";
      default = "sandbox";
      type = types.str;
      description = ''
        The gamemode to run on the server.
        Make sure it's present in `{dataDir}/gamemodes` or downloaded by `workshopCollection`.
      '';
    };
    map = mkOption {
      example = "gms_g4p_stargate_v11";
      default = "gm_construct";
      type = types.str;
      description = ''
        The map to run on the server.
        Make sure it's present in `{dataDir}/maps` or downloaded by `workshopCollection`.
      '';
    };
    workshopCollection = mkOption {
      example = 3035416339;
      default = null;
      type = with types; nullOr int;
      description = ''
        A workshop collection that srcds_run will download before starting the server.
      '';
    };
    package = mkPackageOption pkgs  [ "garrys-mod" "dedicated-server-unwrapped" ] {};
    finalPackage = mkOption {
      type = with types; package;
      default = cfg.package.override { inherit (cfg) extraPaths; };
    };
    extraPaths = mkOption {
      default = [];
      example = [
        (stdenvNoCC.mkDerivation {
          pname = "gmstranded";
          version = "19.00.00";

          src = fetchFromGitHub {
            owner = "TGRCDev";
            repo = "GMStranded";
            rev = "4bc8f7cf88be1c6965282167f6151e754651777d";
            hash = "sha256-6eRWMU75SpgZgYu6bzOSDP0cs879dPgNR8pWqpcGr4A=";
          };

          buildPhase = ''
            mkdir -p $out/garrysmod
            cp -Rs $src/gamemodes $src/particles $src/data $out/garrysmod
          '';
        })
      ];
      type = with types; listOf package;
      description = ''
        A list of derivations whose contents are linked to the fake srcds dir when the
        server is started. Use this to add additional files (maps, gamemodes, scripts, etc.)
        to the server without needing a workshop collection.
      '';
    };
    extraArgs = mkOption {
      example = {
        sv_lan = 1;
        hostname = "My Server";
      };
      default = {};
      type = with types; attrs;
      description = ''
        Additional arguments to pass to `srcds_run`.
      '';
    };
    user = mkOption {
      default = "garrys-mod";
      type = with types; str;
      description = ''
        The user account to run the server with.
      '';
    };
    umask = mkOption {
      default = "077";
      example = "007";
      type = with types; str;
      description = ''
        The `umask` value to run the server with.
      '';
    };
  };

  config = mkMerge [
    {nixpkgs.overlays = [(final: prev: {garrys-mod = gpkgs;})];}
    (mkIf cfg.enable {
      systemd.services.garrys-mod = let
        serverPkg = cfg.finalPackage;
        runWrapper = gpkgs.dedicated-server.override {
          dedicated-server-unwrapped = serverPkg;
          defaultArgs = {
            inherit (cfg) dataDir;
            consoleArgs = {
              inherit (cfg) port gamemode map;
            } // cfg.extraArgs
            // (if cfg.address != null then { ip = cfg.address; } else {})
            // (if cfg.workshopCollection != null then { host_workshop_collection = cfg.workshopCollection; } else {});
          };
        };
      in {
        description = "Garry's Mod dedicated server";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          ExecStart = "${runWrapper}/bin/run-gmod-server";
          UMask = cfg.umask;
        };
      };
      users = mkIf (cfg.user == defaultUser.name) {
        users.garrys-mod = defaultUser;
        groups.garrys-mod = {};
      };
      networking.firewall = mkIf cfg.openFirewall {
        allowedUDPPorts = [ cfg.port ];
      };
    })
  ];
}