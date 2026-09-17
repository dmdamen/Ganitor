public struct Ganitor.TrashResult {
    public uint succeeded;
    public File[] failed_files;
}

public class Ganitor.TrashOperation : GLib.Object {
    // Operates on Gio.File objects throughout, never path strings:
    // File.get_path() returns null for some backends (confirmed for at
    // least one Flatpak document-portal case), which previously crashed
    // this exact path when round-tripped through a string.
    public static File[] selected_files (ListModel groups) {
        var matches = new GenericArray<File> ();

        for (uint i = 0; i < groups.get_n_items (); i++) {
            var group = (DuplicateGroup) groups.get_item (i);
            for (uint j = 0; j < group.files.get_n_items (); j++) {
                var candidate = (CandidateFile) group.files.get_item (j);
                if (candidate.selected) {
                    matches.add (candidate.file);
                }
            }
        }

        var result = new File[matches.length];
        for (uint i = 0; i < matches.length; i++) {
            result[i] = matches[i];
        }
        return result;
    }

    public async TrashResult run (File[] files, Cancellable cancellable) {
        uint succeeded = 0;
        var failed = new GenericArray<File> ();

        foreach (var file in files) {
            try {
                yield file.trash_async (Priority.DEFAULT, cancellable);
                succeeded++;
            } catch (Error e) {
                failed.add (file);
            }
        }

        var failed_files = new File[failed.length];
        for (uint i = 0; i < failed.length; i++) {
            failed_files[i] = failed[i];
        }

        return TrashResult () { succeeded = succeeded, failed_files = failed_files };
    }
}
