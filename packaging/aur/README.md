# AUR submission guide

## first-time setup

```bash
# clone your AUR package repo (after creating it at aur.archlinux.org/packages/lanchat-bin)
git clone ssh://aur@aur.archlinux.org/lanchat-bin.git ~/aur/lanchat-bin
cp PKGBUILD ~/aur/lanchat-bin/
```

## update sha256 after each release

```bash
updpkgsums   # or manually:
curl -L https://github.com/numbpill3d/lanchat/releases/download/v<VER>/lanchat-linux-x64.tar.gz | sha256sum
# paste the hash into PKGBUILD sha256sums=('...')
```

## generate .SRCINFO and push

```bash
cd ~/aur/lanchat-bin
makepkg --printsrcinfo > .SRCINFO
git add PKGBUILD .SRCINFO
git commit -m "update to v<VER>"
git push
```

## test locally first

```bash
cd ~/aur/lanchat-bin
makepkg -si
```
