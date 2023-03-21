# FoundryVTT a la NixOS

These configurations allow for easily creating a multi-tenant FoundryVTT host.

## Notes

The `configuration.nix` is provided for your convenience while these configs are cleaned up. This 
has been my learning project to get used to Nix/NixOS, and so there's definitely details that 
could be better. I would love PRs, especially to enhance security and idiomatics! It would also 
be welcome to convert this into a Flake, though I'm still yet to pick up Flakes.

## Backups

I setup backups for this on my machine, I recommend [this](https://xeiaso.net/blog/borg-backup-2021-01-09) for reading.

## Future goals

- [ ] Flake
- [ ] Per-container features
- [ ] Moar options

