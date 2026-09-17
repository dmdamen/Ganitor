public class Ganitor.EmptyFolderScanner : GLib.Object {
    public ListStore folders { get; private set; }

    public signal void error_occurred (File location, Error error);
    public signal void completed ();
    public signal void cancelled ();

    construct {
        folders = new ListStore (typeof (EmptyFolder));
    }

    public void select_all () {
        for (uint i = 0; i < folders.get_n_items (); i++) {
            ((EmptyFolder) folders.get_item (i)).selected = true;
        }
    }

    // Never offers `root` itself, even if the whole tree beneath it turns
    // out to be empty: removing the folder the user explicitly chose to
    // scan would be surprising. So the root is walked one level specially,
    // examining each of its direct subdirectories as its own candidate.
    public async void run (File root, Cancellable cancellable) {
        try {
            var subdirs = yield list_subdirs (root, cancellable);
            foreach (var subdir in subdirs) {
                GenericArray<File>? nested;
                try {
                    nested = yield scan_dir (subdir, cancellable);
                } catch (IOError.CANCELLED e) {
                    cancelled ();
                    return;
                }

                if (nested == null) {
                    folders.append (new EmptyFolder (subdir));
                } else {
                    foreach (var candidate in nested) {
                        folders.append (new EmptyFolder (candidate));
                    }
                }
            }
        } catch (IOError.CANCELLED e) {
            cancelled ();
            return;
        }

        completed ();
    }

    // Returns null if `dir` and everything inside it contains no regular
    // files (only possibly nested empty directories) - the caller should
    // treat `dir` itself as a single candidate in that case. Otherwise
    // returns the maximal empty subdirectories found within `dir` (`dir`
    // itself is not empty, so it is never a candidate).
    private async GenericArray<File>? scan_dir (File dir, Cancellable cancellable) throws IOError {
        bool has_file;
        var subdirs = yield list_subdirs (dir, cancellable, out has_file);

        var found = new GenericArray<File> ();
        bool all_subdirs_empty = true;

        foreach (var subdir in subdirs) {
            var nested = yield scan_dir (subdir, cancellable);
            if (nested == null) {
                found.add (subdir);
            } else {
                all_subdirs_empty = false;
                foreach (var candidate in nested) {
                    found.add (candidate);
                }
            }
        }

        if (!has_file && all_subdirs_empty) {
            return null;
        }
        return found;
    }

    private async GenericArray<File> list_subdirs (File dir, Cancellable cancellable, out bool has_file = null) throws IOError {
        var subdirs = new GenericArray<File> ();
        has_file = false;

        FileEnumerator enumerator;
        try {
            enumerator = yield dir.enumerate_children_async (
                "standard::name,standard::type",
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                Priority.DEFAULT,
                cancellable
            );
        } catch (IOError.CANCELLED e) {
            throw e;
        } catch (Error e) {
            error_occurred (dir, e);
            return subdirs;
        }

        while (true) {
            List<FileInfo> infos;
            try {
                infos = yield enumerator.next_files_async (32, Priority.DEFAULT, cancellable);
            } catch (IOError.CANCELLED e) {
                throw e;
            } catch (Error e) {
                error_occurred (dir, e);
                break;
            }

            if (infos.length () == 0) {
                break;
            }

            foreach (var info in infos) {
                var type = info.get_file_type ();
                if (type == FileType.DIRECTORY) {
                    subdirs.add (dir.get_child (info.get_name ()));
                } else {
                    // Symlinks count as content too (not skipped, unlike
                    // the duplicate scanner): a folder containing only a
                    // symlink isn't safe to casually offer for removal as
                    // "empty", since deleting it would also destroy that
                    // symlink without the user necessarily noticing.
                    has_file = true;
                }
            }
        }

        return subdirs;
    }
}
