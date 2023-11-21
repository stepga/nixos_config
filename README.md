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

- [ ] add `rclone` timer & service, syncing nextcloud
- [ ] use authorized_keys from secrets.nix
- [ ] imprison some clients via nftables
- [ ] flakes & home-manager (?)
