public class Ganitor.DuplicateGroupRow : Adw.ExpanderRow {
    public DuplicateGroup group { get; construct; }

    public signal void selection_toggled ();

    public DuplicateGroupRow (DuplicateGroup group) {
        Object (group: group);
    }

    construct {
        var count = group.files.get_n_items ();

        title = "%u Identical Files".printf (count);
        subtitle = "%s each — %s wasted".printf (
            GLib.format_size (group.size),
            GLib.format_size (group.wasted_bytes)
        );

        for (uint i = 0; i < count; i++) {
            var candidate = (CandidateFile) group.files.get_item (i);
            var row = new CandidateFileRow (candidate);
            row.selection_toggled.connect (() => selection_toggled ());
            add_row (row);
        }
    }
}
