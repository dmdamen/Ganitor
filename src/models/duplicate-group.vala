public class Ganitor.DuplicateGroup : GLib.Object {
    public string checksum { get; construct; }
    public int64 size { get; construct; }
    public ListStore files { get; private set; }

    public int64 wasted_bytes {
        get { return size * (files.get_n_items () - 1); }
    }

    public DuplicateGroup (string checksum, int64 size) {
        Object (checksum: checksum, size: size);
    }

    construct {
        files = new ListStore (typeof (CandidateFile));
    }

    // Deliberately does not listen for CandidateFile.notify["selected"] here:
    // a plain GObject connecting to a signal on an object it also owns via
    // `files` creates an unbreakable reference cycle (neither side's refcount
    // can ever reach zero), unlike GTK widgets whose dispose() chain severs
    // such cycles automatically. UI code should watch selection changes at
    // the widget layer instead (see CandidateFileRow/DuplicateGroupRow).
    public void add_file (CandidateFile candidate) {
        files.append (candidate);
    }
}
