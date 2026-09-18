# Ganitor

A GNOME application for finding and removing duplicate files, built with
Vala, GTK4, and libadwaita.

Ganitor scans a folder you choose, groups files first by size and then by a
SHA-256 content hash, and shows you the resulting duplicate groups so you can
select which copies to move to the trash.

![Ganitor showing duplicate file groups found in a folder](https://raw.githubusercontent.com/dmdamen/Ganitor/master/data/screenshots/results.png)

## AI disclosure

This application was built entirely by an AI coding assistant (Claude, by
Anthropic), directed and reviewed by the developer. All code, tests, and the
Flatpak packaging were AI-generated rather than hand-written.

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
