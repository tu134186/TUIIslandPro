# 灵动岛 Pro / IslandPro

**V1.0.0 experimental prototype, not a finished clone.** Rootless iOS 16–17 project.

## Implemented in source
- SpringBoard injection and SBSystemApertureContainerView layout hook
- Opt-in static image overlay using an absolute local image path
- Opacity, scale, X/Y offsets and a configurable cyan static glow
- Preferences with Darwin notification reload and cached image loading
- Dedicated GitHub Actions workflow for this repository

## Not implemented or not verified
- File picker, GIF, MP4, dual animation, animated glow/particles
- Recording/music/notification lifecycle, conflict detection
- Cloud build success and on-device compatibility have not been confirmed

**Safety:** Keep the tweak disabled until testing. Do not enable alongside ios16dao. No proprietary reference dylib is included.

Repository build workflow is independent of all other repositories.
