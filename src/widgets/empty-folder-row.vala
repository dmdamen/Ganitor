public class Ganitor.EmptyFolderRow : Adw.ActionRow {
    public EmptyFolder folder { get; construct; }
    public File scan_root { get; construct; }

    public signal void selection_toggled ();

    public EmptyFolderRow (EmptyFolder folder, File scan_root) {
        Object (folder: folder, scan_root: scan_root);
    }

    construct {
        title = PathDisplay.relative_path (scan_root, folder.file);

        var check = new Gtk.CheckButton () {
            valign = Gtk.Align.CENTER,
        };
        // See CandidateFileRow for why this binds from folder onto check,
        // not the other way round.
        folder.bind_property (
            "selected",
            check, "active",
            BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE
        );
        check.toggled.connect (() => selection_toggled ());
        add_prefix (check);
        activatable_widget = check;
    }
}
