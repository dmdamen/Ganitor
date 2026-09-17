namespace Ganitor.PathDisplay {
    // `target`'s path relative to `scan_root` (e.g. "Videos/2019/clip.mp4").
    // Falls back to target's own path/display name if it isn't actually a
    // descendant of scan_root, which shouldn't happen in practice since
    // every candidate the app shows comes from scanning scan_root itself.
    public string relative_path (File scan_root, File target) {
        return scan_root.get_relative_path (target) ?? (target.get_path () ?? target.get_parse_name ());
    }

    // The directory containing `target`, relative to `scan_root` (e.g.
    // "Videos/2019"). For a file directly inside scan_root, there's no
    // relative parent to show, so this falls back to scan_root's own
    // display name instead.
    public string relative_parent_directory (File scan_root, File target) {
        var parent = target.get_parent ();
        if (parent == null || parent.equal (scan_root)) {
            return Path.get_basename (scan_root.get_path () ?? scan_root.get_parse_name ());
        }
        return relative_path (scan_root, parent);
    }
}
