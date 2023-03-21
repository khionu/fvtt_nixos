{ config, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./fvtt_mod.nix
    ];

  fvtt.enable = true;
  fvtt.instances = import ./fvtt_instances.nix;
  fvtt.acmeEmail = "you@example.com";

  # All of the below is necessary for the Foundry containers to
  # be able to reach the internet.
  networking.hostName = "vtt";
  networking.networkmanager.enable = true;
  networking.nat = {
    enable = true;
    externalInterface = "enp1s0";
    internalInterfaces = [ "ve-fvtt-*" ];
  };
  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
    checkReversePath = false;
    # I don't remember why this is necessary, but it is.
    extraCommands = "iptables -t nat -A POSTROUTING -o enp1s0 -j MASQUERADE";
  };

  time.timeZone = "UTC";

  i18n.defaultLocale = "en_US.UTF-8";
  console.font = "Lat2-Terminus16";

  users.users.you = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [];
  };

  programs.starship.enable = true;

  environment.systemPackages = with pkgs; [
    # I'd like to take this opportunity to introduce you
    # to a bunch of RustLang CLI tools :D
    du-dust xplr bat exa zoxide zellij delta ripgrep bandwhich fd
    # and some other tools that might be useful during hosting
    neovim wget procs htop git zip unzip
  ];

  services.openssh.enable = true;
  services.tailscale.enable = true;

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "22.05";
}

