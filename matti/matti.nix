# NIX_PATH=nixpkgs=https://github.com/NixOS/nixpkgs/archive/refs/heads/nixos-unstable.zip nix-build -A pix.ipxe

{
  system ? "x86_64-linux",
  nixpkgs ? import <nixpkgs> {},
  nixos ? import <nixpkgs/nixos> {},
}:

let
  nixosWNetBoot = import <nixpkgs/nixos> {

  configuration = { config, pkgs, lib, ... }: with lib; {

    networking.hostName = "RAMsteam";
    time.timeZone = "Europe/Helsinki";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    ## Performance tweaks
    boot.kernelParams = [
      "mitigations=off"
    ];

    boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_latest);
    boot.initrd.availableKernelModules = [ "squashfs" "overlay" ];
    boot.initrd.kernelModules = [ "loop" "overlay" ];

    ## User
    users.users.nixos = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" "video" ];
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCuc2L4Q39X4y/pYNpd4hb4UuDUdjzv+z/mFELSsHGzPFDpS0H+TbCj6tVGqsk/sF+KBDb9HKxZvEMGyJokcxirnlWjYeRblgvOxVeEjJbnvwtlw3NCsI901fRCBzU9Un0jnuQAzPkv/NjJs2bz9CKSoDEvGq2SGLE5jTAUJSaHf9BGaZIkf5IjTzqurekdeBy7aZkm3j1DEeKJxOONgfqDsD3owKVLBLtf1Rnf19rZYGAnXMQlQSb3Tdn921fB77nrUIsi1ImBVok5fOrSjiPWBEDPl+Xik3H1ru1X+dB3AQhsAvICt3IUbm1+1yP4aoEu2n+Q4I7qnjlzBehO5/S3Sv3RdxwNic6upHH1bDfHMcMMc4BQqjSnDqOWPi7yC2JPKm0A5ihw/3rxLr0RTX76IbqMqjbyP9210znlfVu8pG4e7aDkioTy4rgEfd+BnfrMtb9gzb9VvXWGS4Togi8xHm0s2Kms0QuozJ+LTNgQcaGJLl/I8AW4vVh8NSoR8ki/60ayWunO+FtbBlUtFSlC5wkuELNxU9nYWenlNQG3CnjCsebj3lnQDsdQMgRqnyWNcw/AJrIs6LE7/8nmRTWd3TwIL51gd+Yj7ONMNYK0ja+h4LxB93YGwEpfeSfXZjNlQNyV8gLxrdqtMzzFuNn/re0jKAVCCD+lvix5+lzYpQ== Juuso’siPhone"
      ];
    };

    ## Allow the user to log in as root without a password.
    users.users.root.initialHashedPassword = "";

    ## Allow passwordless sudo from nixos user
    security.sudo = {
      enable = mkDefault true;
      wheelNeedsPassword = mkForce false;
    };

    ## Automatically log in at the virtual consoles.
    services.getty.autologinUser = "nixos";

    services.openssh = {
      enable = true;
      passwordAuthentication = false;
    };

    ## Gaming start
    nixpkgs.config.allowUnfree = true;
    programs.steam.enable = true;
    networking.firewall.enable = false;
    programs.gamemode = {
      enable = true;
      settings = {
        general = {
          renice = 10;
        };

        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
          amd_performance_level = "high";
        };
      };
    };

    # enable the RealtimeKit system service, which hands out realtime
    # scheduling priority to user processes on demand. For example, the
    # PulseAudio server uses this to acquire realtime priority.
    security.rtkit.enable = true;
    environment.systemPackages = [
      # a Steam dependancy
      pkgs.libblockdev
      pkgs.discord
      # Install and Update Proton-GE
      # https://github.com/GloriousEggroll/proton-ge-custom
      # README: https://github.com/AUNaseef/protonup
      # protonup --download
      pkgs.protonup
      # A Vulkan and OpenGL overlay for monitoring FPS, temperatures, CPU/GPU load and more.
      # https://github.com/flightlessmango/MangoHud
      # To enable: MANGOHUD=1 MANGOHUD_CONFIG=full steam
      pkgs.mangohud
      # debug utils for graphics
      # pkgs.glxinfo
      pkgs.vulkan-tools
      # Upscaler
      # pkgs.vkBasalt
      # Mixer and audio control
      pkgs.easyeffects
      pkgs.helvum
      # pkgs.lutris
      # https://github.com/Plagman/gamescope
      pkgs.gamescope
    ];

    ## 64 and 32 bit Vulkan support
    hardware.opengl.driSupport = true;
    hardware.opengl.driSupport32Bit = true;

    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.vulkan_beta;

    ## Steam Remote Play
    #### Controllers
    #hardware.steam-hardware.enable = true;
    #hardware.xpadneo.enable = true;
    ##
    ##  $ bluetoothctl
    ##  [bluetooth] # power on
    ##  [bluetooth] # agent on
    ##  [bluetooth] # default-agent
    ##  [bluetooth] # scan on
    ##  ...put device in pairing mode and wait [hex-address] to appear here...
    ##  [bluetooth] # pair [hex-address]
    ##  [bluetooth] # connect [hex-address]
    #hardware.bluetooth.enable = true;
    #### Audio
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    ### System APIs
    services.dbus.enable = true;

    ## Window manager
    programs.sway.enable = true;
    environment.loginShellInit = ''
      [[ "$(tty)" == /dev/tty1 ]] && sway
    '';

    ## Firmware blobs
    hardware.enableRedistributableFirmware = true;

    fileSystems."/" = mkImageMediaOverride {
      fsType = "tmpfs";
      options = [ "mode=0755" ];
    };

    # In stage 1, mount a tmpfs on top of /nix/store (the squashfs
    # image) to make this a live CD.
    fileSystems."/nix/.ro-store" = mkImageMediaOverride {
      fsType = "squashfs";
      device = "../nix-store.squashfs";
      options = [ "loop" ];
      neededForBoot = true;
    };

    fileSystems."/nix/.rw-store" = mkImageMediaOverride {
      fsType = "tmpfs";
      options = [ "mode=0755" ];
      neededForBoot = true;
    };

    fileSystems."/nix/store" = mkImageMediaOverride {
      fsType = "overlay";
      device = "overlay";
      options = [
        "lowerdir=/nix/.ro-store"
        "upperdir=/nix/.rw-store/store"
        "workdir=/nix/.rw-store/work"
      ];

      depends = [
        "/nix/.ro-store"
        "/nix/.rw-store/store"
        "/nix/.rw-store/work"
      ];
    };

    # Create the squashfs image that contains the Nix store.
    system.build.squashfsStore = pkgs.callPackage <nixpkgs/nixos/lib/make-squashfs.nix> {
      # Closures to be copied to the Nix store, namely the init
      # script and the top-level system configuration directory.
      storeContents = [ config.system.build.toplevel ];
    };

    # Create the initrd
    system.build.netbootRamdisk = pkgs.makeInitrdNG {
      compressor = "zstd";
      prepend = [ "${config.system.build.initialRamdisk}/initrd" ];
      contents = [{
        object = config.system.build.squashfsStore;
        symlink = "/nix-store.squashfs";
      }];
    };

    system.build.netbootIpxeScript = pkgs.writeTextDir "netboot.ipxe" ''
      #!ipxe
      # Use the cmdline variable to allow the user to specify custom kernel params
      # when chainloading this script from other iPXE scripts like netboot.xyz
      kernel ${pkgs.stdenv.hostPlatform.linux-kernel.target} init=${config.system.build.toplevel}/init initrd=initrd ${toString config.boot.kernelParams} ''${cmdline}
      initrd initrd
      boot
    '';

    # A script invoking kexec on ./bzImage and ./initrd.gz.
    # Usually used through system.build.kexecTree, but exposed here for composability.
    system.build.kexecScript = pkgs.writeScript "kexec-boot" ''
      #!/usr/bin/env bash
      if ! kexec -v >/dev/null 2>&1; then
        echo "kexec not found: please install kexec-tools" 2>&1
        exit 1
      fi
      SCRIPT_DIR=$( cd -- "$( dirname -- "''${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
      kexec --load ''${SCRIPT_DIR}/bzImage \
        --initrd=''${SCRIPT_DIR}/initrd.gz \
        --command-line "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}"
      kexec -e
    '';

    # A tree containing initrd.gz, bzImage and a kexec-boot script.
    system.build.kexecTree = pkgs.linkFarm "kexec-tree" [
      {
        name = "initrd.gz";
        path = "${config.system.build.netbootRamdisk}/initrd";
      }
      {
        name = "bzImage";
        path = "${config.system.build.kernel}/${config.system.boot.loader.kernelFile}";
      }
      {
        name = "kexec-boot";
        path = config.system.build.kexecScript;
      }
    ];

    boot.loader.timeout = 10;

    boot.postBootCommands =
      ''
        # After booting, register the contents of the Nix store in the Nix database in the tmpfs.
        ${config.nix.package}/bin/nix-store --load-db < /nix/store/nix-path-registration
        # nixos-rebuild also requires a "system" profile and an /etc/NIXOS tag.
        touch /etc/NIXOS
        ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
      '';
  };
};

mkNetboot = nixpkgs.pkgs.symlinkJoin {
  name = "netboot";
  paths = with nixosWNetBoot.config.system.build; [ netbootRamdisk kernel netbootIpxeScript ];
  preferLocalBuild = true;
};

in { pix.ipxe = mkNetboot; }