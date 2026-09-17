public struct Ganitor.TrashResult {
    public uint succeeded;
    public string[] failed_paths;
}

public class Ganitor.TrashOperation : GLib.Object {
    public static string[] selected_paths (ListModel groups) {
        var matches = new GenericArray<string> ();

        for (uint i = 0; i < groups.get_n_items (); i++) {
            var group = (DuplicateGroup) groups.get_item (i);
            for (uint j = 0; j < group.files.get_n_items (); j++) {
                var candidate = (CandidateFile) group.files.get_item (j);
                if (candidate.selected) {
                    matches.add (candidate.path);
                }
            }
        }

        var result = new string[matches.length];
        for (uint i = 0; i < matches.length; i++) {
            result[i] = matches[i];
        }
        return result;
    }

    public async TrashResult run (string[] paths, Cancellable cancellable) {
        uint succeeded = 0;
        var failed = new GenericArray<string> ();

        foreach (var path in paths) {
            var file = File.new_for_path (path);
            try {
                yield file.trash_async (Priority.DEFAULT, cancellable);
                succeeded++;
            } catch (Error e) {
                failed.add (path);
            }
        }

        var failed_paths = new string[failed.length];
        for (uint i = 0; i < failed.length; i++) {
            failed_paths[i] = failed[i];
        }

        return TrashResult () { succeeded = succeeded, failed_paths = failed_paths };
    }
}
