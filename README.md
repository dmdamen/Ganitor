# Ganitor

A GNOME application for finding and removing duplicate files, built with
Vala, GTK4, and libadwaita.

Ganitor scans a folder you choose, groups files first by size and then by a
SHA-256 content hash, and shows you the resulting duplicate groups so you can
select which copies to move to the trash.

## Building

```sh
meson setup build
meson compile -C build
./build/src/ganitor
```

## Testing

```sh
meson setup build -Db_coverage=true
meson test -C build
ninja coverage-html -C build
```

## Flatpak

```sh
flatpak-builder --user --force-clean --install build-flatpak build-aux/flatpak/io.github.dmdamen.Ganitor.json
flatpak run io.github.dmdamen.Ganitor
```

## License

GPL-3.0-or-later. See [COPYING](COPYING).
