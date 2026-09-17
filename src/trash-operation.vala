public struct Ganitor.TrashResult {
    public File[] succeeded_files;
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

    // Reports which files succeeded/failed directly in the result, rather
    // than making the caller re-derive it from the original `files`
    // argument afterward: a caller that captures that array parameter only
    // inside a run.begin(...) callback (as opposed to referencing it via
    // `yield` within an async method) can end up with a corrupted/
    // zero-length copy by the time the callback fires. This was the actual
    // cause of a real crash - confirmed via coredumpctl showing the
    // captured array's length reading back as 0 inside such a callback.
    public async TrashResult run (File[] files, Cancellable cancellable) {
        var succeeded = new GenericArray<File> ();
        var failed = new GenericArray<File> ();

        foreach (var file in files) {
            try {
                yield file.trash_async (Priority.DEFAULT, cancellable);
                succeeded.add (file);
            } catch (Error e) {
                warning ("trash_async failed for %s: %s", file.get_uri (), e.message);
                failed.add (file);
            }
        }

        var succeeded_files = new File[succeeded.length];
        for (uint i = 0; i < succeeded.length; i++) {
            succeeded_files[i] = succeeded[i];
        }

        var failed_files = new File[failed.length];
        for (uint i = 0; i < failed.length; i++) {
            failed_files[i] = failed[i];
        }

        return TrashResult () { succeeded_files = succeeded_files, failed_files = failed_files };
    }
}
