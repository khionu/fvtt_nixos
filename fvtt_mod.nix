{ lib, pkgs, config, ... }:
with lib;
let
  # Extract a few options for readability
  cfg = config.fvtt;
  instances = cfg.instances;
  host = config.networking.hostName;

  # Generate the nginx virtualhosts
  vhosts = listToAttrs (map (x:
    nameValuePair "${x.ident}.${host}" {
      # Enables HTTP -> HTTPS redirect
      forceSSL = true;
      # We're using the root of the host as the central cert
      useACMEHost = host;
      # This will proxy requests to the private IP of the instance's container
      locations."/" = {
        proxyPass = "http://${x.ip}:8080/";
        proxyWebsockets = true;
      };
    }
  ) (builtins.attrValues instances));

  # Generate the list of domains
  domains = map (x: "${x.ident}.${host}") (builtins.attrValues instances);
in {
  # Define the NixOS module option
  options.fvtt = {
    enable = mkEnableOption "foundry vtt";
    instances = mkOption.type = types.anything;
    acmeEmail = mkOption.type = types.string;
  };
  
  # If Foundry is enabled, we make all of the below happen
  config = mkIf cfg.enable {
    # Global Let's Encrypt settings
    security.acme.acceptTerms = true;
    security.acme.defaults.email = cfg.acmeEmail;
    security.acme.defaults.webroot = ".well-known/acme-challenge/";
    users.users.nginx.extraGroups = [ "acme" ];

    # Setup the nginx proxy layer
    services.nginx = {
      # Turn on nginx with the essential configurations
      enable = true;

      # Enable some recommend configurations
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;

      # Restrict SSL to a better set of ciphers
      sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";
   
      # Add all the generated vhosts, plus one root which will have the
      # other domains attached
      virtualHosts = vhosts // {
        "${host}".enableACME = true;
      };
    };
   
    # We have the instance domains -> root cert relationship above, but
    # we need the root cert -> instance domains relationship here
    security.acme.certs."${host}".extraDomainNames = domains;

    # Each instance goes in a container to make it easier to have them all
    # side by side.
    containers = listToAttrs (map (x:
      nameValuePair "fvtt-${x.ident}" {
        # Ephemeral means that anything not getting stored in a bindmount gets dropped.
        # Keep your environments sparkly!!
        ephemeral = true;
        # We want these containers to start up with the host machine
        autoStart = true;

        # The private network is what gives us the practical (not secure) network isolation
        # that enables the side-by-side instances of Foundry
        privateNetwork = true;
        hostAddress = "192.168.0.1";
        localAddress = x.ip;
        macvlans = [ "enp1s0" ];
   
        # We make each instance's folder a subfolder on the host. Convenient for backups!
        bindMounts."/opt/fvtt/" = {
          hostPath = "/opt/fvtt/${x.ident}/";
          isReadOnly = false;
        };
   
        # The cache holds the base copy of Foundry. Just need it to bootstrap the instance.
        bindMounts."/opt/fvtt_static" = {
          hostPath = "/opt/fvtt_static/";
          isReadOnly = true; # It's still modifyable from the host, this is for correctness
        };
   
        # This config is the "system module" of the container. Guest like host, this defines
        # the essentials of the container, as well as the systemd unit that will run Foundry
        config = { config, pkgs, ... }: {
          # Network security is not a current* goal, not between the containers or container 
          # and host.
          #
          # * PRs welcome!
          networking.firewall.enable = false;
   
          # And finally, FOUNDRY
          systemd.services.foundry = {
            description = "FoundryVTT";
            after = [ "network.target" ];
            wants = [ "network-online.target" ];
            # This sets up and executes Foundry. Sadly, a bash wrapper is necessary for some parts
            script = "exec ${pkgs.callPackage ./fvtt_pkg.nix {}}/bin/foundryvtt-bootstrap";
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              RestartSec = 1;     # There's a weird race condition that makes the delay necessary
              Restart = "always"; # Foundry sometimes requires a restart as part of some settings changes
            };
          };

          # These are the static options that need to be hard set. If edited from within Foundry,
          # Foundry will restart, and the bootstrap script will overwrite the options.json with
          # these values. This is to prevent the user from breaking their instance and requiring
          # manual intervention.
          environment.etc."fvtt/options.json".text = builtins.toJSON {
            port = 8080;
            dataPath = "/opt/fvtt/data/";
            hostname = "${x.ident}.${host}";
            upnp = true;
            proxySSL = true;
            proxyPort = 443;
          };
        };
      }) (builtins.attrValues instances));
    };
  };
}
