My NixOS configuration for my apu2d4 router

## Secrets

Secrets are stored in `secrets.nix`, which looks something like this:

```
{
  name = {
    username = "foo";
    password = "bar";
  };
}
```

## TODOs

- [ ] use authorized_keys from secrets.nix
- [ ] imprison some clients via nftables
- [ ] systemd.services.rclone-nextcloud
  - [ ] /tmp/rclone.config is world-readable, never deleted
  - [ ] /tmp/rclone.config should be replace by something like bash's process substitution
  - [ ] disk-usage of /usb should be considered
- [ ] flakes & home-manager (?)
