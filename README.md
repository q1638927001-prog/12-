# LockColorSwitch — RootHide / GitHub Actions

Target: iOS 16.6.1, iPhone 14 Pro Max, RootHide.

## Intended behavior

- Lock-screen notifications: foreground text/UI only, white/black/default.
- Lock-screen media player: foreground text/UI only, white/black/default.
- Lock-screen Live Activity: lock-screen presentation only, foreground text/UI only, white/black/default.
- No background changes.
- No Dynamic Island changes.

## Important

This repository is a first-pass buildable scaffold. iOS private UI classes are not available for validation in this cloud environment. Test on a non-critical setup first. If a target does not recolor, its private view hierarchy/class names need to be identified on iOS 16.6.1 and the hook narrowed accordingly.

## GitHub Actions

Open Actions -> Build RootHide Deb -> Run workflow.

The generated `.deb` is uploaded as an Actions artifact.
