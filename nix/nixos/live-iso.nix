{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-base.nix") ];

  networking.hostName = "devos";
  services.devos.enable = true;
  users.users.dev.initialPassword = "dev";

  # The live image uses a writable RAM overlay and has no target disk layout.
  # Both firmware boot and writing the ISO directly to a USB stick are supported.
  isoImage = {
    volumeID = "DEVOS";
    makeEfiBootable = true;
    makeUsbBootable = true;
    appendToMenuLabel = " DevOS";
  };
  image.fileName = "devos-x86_64.iso";
  boot.zfs.forceImportRoot = false;

  # NetworkManager enables and controls wpa_supplicant through D-Bus.
  services.getty.autologinUser = lib.mkForce "dev";
  boot.kernelParams = [
    "console=ttyS0,115200"
    "console=tty0"
  ];
  system.stateVersion = "26.05";
}
