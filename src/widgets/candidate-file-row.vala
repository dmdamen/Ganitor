public class Ganitor.CandidateFileRow : Adw.ActionRow {
    public CandidateFile candidate { get; construct; }

    // Fired from the checkbox's own "toggled" signal. Widget-to-widget
    // connections like this are safe from the reference-cycle problem that
    // rules out listening for selection changes at the model layer (see
    // DuplicateGroup) because GTK's dispose chain severs them automatically.
    public signal void selection_toggled ();

    public CandidateFileRow (CandidateFile candidate) {
        Object (candidate: candidate);
    }

    construct {
        title = Path.get_basename (candidate.path);
        subtitle = "%s — modified %s".printf (
            Path.get_dirname (candidate.path),
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
}
