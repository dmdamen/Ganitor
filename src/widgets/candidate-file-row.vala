public class Ganitor.CandidateFileRow : Adw.ActionRow {
    public CandidateFile candidate { get; construct; }

    // The folder the user picked to scan. Under Flatpak, candidate.path is a
    // document-portal FUSE path (e.g. /run/user/1000/doc/<id>/...) that means
    // nothing to the user, so the subtitle shows the path relative to this
    // root instead of the raw absolute path.
    public File scan_root { get; construct; }

    // Fired from the checkbox's own "toggled" signal. Widget-to-widget
    // connections like this are safe from the reference-cycle problem that
    // rules out listening for selection changes at the model layer (see
    // DuplicateGroup) because GTK's dispose chain severs them automatically.
    public signal void selection_toggled ();

    public CandidateFileRow (CandidateFile candidate, File scan_root) {
        Object (candidate: candidate, scan_root: scan_root);
    }

    construct {
        title = Path.get_basename (candidate.path);
        subtitle = "%s — modified %s".printf (
            relative_directory (),
            candidate.modified_time.format ("%Y-%m-%d %H:%M")
        );

        var check = new Gtk.CheckButton () {
            valign = Gtk.Align.CENTER,
        };
        check.bind_property (
            "active",
            candidate, "selected",
            BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE
        );
        check.toggled.connect (() => selection_toggled ());
        add_prefix (check);
        activatable_widget = check;
    }

    private string relative_directory () {
        var relative = scan_root.get_relative_path (candidate.file);
        if (relative == null) {
            return Path.get_dirname (candidate.path);
        }

        var relative_dir = Path.get_dirname (relative);
        if (relative_dir == ".") {
            return Path.get_basename (scan_root.get_path () ?? scan_root.get_parse_name ());
        }

        return relative_dir;
    }
}
