{
  config,
  pkgs,
  ...
}:

{
  power.ups = {
    enable = true;
    mode = "standalone";

    upsd.listen = [
      {
        address = "0.0.0.0";
        port = 3493;
      }
    ];

    ups.cyberpower = {
      driver = "usbhid-ups";
      port = "auto";
      description = "CyberPower CP1500 AVR UPS";
      directives = [
        "ignorelb"
        "lowbatt = 90"
      ];
    };

    upsmon.monitor.cyberpower = {
      user = "upsmon";
      passwordFile = "/etc/nixos/secrets/ups-password.txt";
      system = "cyberpower@localhost";
      type = "master";
    };

    users.upsmon = {
      passwordFile = "/etc/nixos/secrets/ups-password.txt";
      upsmon = "primary";
    };
  };
}
