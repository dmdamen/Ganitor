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

    // Keeps the oldest copy unselected (most likely the original) and
    // selects every other copy for removal, so the UI has a sensible
    // default the user can review and adjust rather than starting empty.
    public void auto_select_duplicates () {
        var count = files.get_n_items ();
        if (count < 2) {
            return;
        }

        uint keep_index = 0;
        DateTime oldest = ((CandidateFile) files.get_item (0)).modified_time;
        for (uint i = 1; i < count; i++) {
            var candidate = (CandidateFile) files.get_item (i);
            if (candidate.modified_time.compare (oldest) < 0) {
                oldest = candidate.modified_time;
                keep_index = i;
            }
        }

        for (uint i = 0; i < count; i++) {
            var candidate = (CandidateFile) files.get_item (i);
            candidate.selected = (i != keep_index);
        }
    }
}
