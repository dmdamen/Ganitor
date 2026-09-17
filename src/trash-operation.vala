public struct Ganitor.TrashResult {
    public File[] succeeded_files;
    public File[] failed_files;
}

public class Ganitor.TrashOperation : GLib.Object {
    private File trash_dir;

    // trash_dir defaults to the real, shared trash directory
    // (~/.local/share/Trash) so files trashed here show up in Nautilus
    // like anywhere else. Deliberately built from get_home_dir() rather
    // than Environment.get_user_data_dir(): inside a Flatpak sandbox,
    // $XDG_DATA_HOME is normally remapped to the app's private data
    // directory, which is not the shared trash location the
    // xdg-data/Trash filesystem permission actually grants access to.
    // Tests inject a scratch directory instead of touching the real one.
    public TrashOperation (File? trash_dir = null) {
        this.trash_dir = trash_dir ?? File.new_for_path (
            Path.build_filename (Environment.get_home_dir (), ".local", "share", "Trash")
        );
    }

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
                    if (candidate.file == null) {
                        warning ("selected_files: candidate.file is null, skipping");
                        continue;
                    }
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

    public static File[] selected_folders (ListModel folders) {
        var matches = new GenericArray<File> ();

        for (uint i = 0; i < folders.get_n_items (); i++) {
            var folder = (EmptyFolder) folders.get_item (i);
            if (folder.selected) {
                matches.add (folder.file);
            }
        }

        var result = new File[matches.length];
        for (uint i = 0; i < matches.length; i++) {
            result[i] = matches[i];
        }
        return result;
    }

    // Trashing is implemented by hand (copy into trash_dir/files, write a
    // .trashinfo record, delete the original) rather than via
    // Gio.File.trash_async(): that call hard-refuses to trash anything on
    // the document-portal's FUSE mount, which is the only kind of path
    // Ganitor ever sees under portal-only sandboxing (confirmed via
    // `gio trash` reproducing "Trashing on system internal mounts is not
    // supported" on the exact same path outside the sandbox too - this is
    // a GLib restriction, not a missing permission). Reports which files
    // succeeded/failed directly in TrashResult, computed here while
    // `files` is still a normal async-method parameter, rather than
    // making the caller re-derive it from the original array afterward:
    // capturing an array *parameter* and reading it from a run.begin(...)
    // callback (as opposed to via `yield` inside this method) corrupted it
    // in a real, confirmed crash.
    public async TrashResult run (File[] files, Cancellable cancellable) {
        var succeeded = new GenericArray<File> ();
        var failed = new GenericArray<File> ();

        ensure_directory (trash_dir.get_child ("files"), cancellable);
        ensure_directory (trash_dir.get_child ("info"), cancellable);

        foreach (var file in files) {
            try {
                yield trash_entry (file, cancellable);
                succeeded.add (file);
            } catch (Error e) {
                warning ("failed to trash %s: %s", file.get_uri (), e.message);
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

    private void ensure_directory (File dir, Cancellable cancellable) {
        try {
            dir.make_directory_with_parents (cancellable);
        } catch (IOError.EXISTS e) {
            // already there
        } catch (Error e) {
            warning ("failed to create %s: %s", dir.get_path (), e.message);
        }
    }

    // Handles both files and empty directories: Gio.File.copy_async()
    // refuses to copy a directory source outright (it doesn't recurse), but
    // since a directory reaching this method is always empty (the only
    // caller for directories is the empty-folder cleanup phase), creating
    // an equivalent empty directory at the destination is sufficient.
    private async void trash_entry (File file, Cancellable cancellable) throws Error {
        var basename = file.get_basename () ?? "file";
        var destination = pick_unique_destination (basename, cancellable);
        var file_type = file.query_file_type (FileQueryInfoFlags.NOFOLLOW_SYMLINKS, cancellable);

        if (file_type == FileType.DIRECTORY) {
            yield destination.make_directory_async (Priority.DEFAULT, cancellable);
        } else {
            yield file.copy_async (
                destination,
                FileCopyFlags.NONE,
                Priority.DEFAULT,
                cancellable,
                null
            );
        }

        yield write_trashinfo (destination.get_basename (), file, cancellable);
        yield file.delete_async (Priority.DEFAULT, cancellable);
    }

    private File pick_unique_destination (string basename, Cancellable cancellable) {
        var files_dir = trash_dir.get_child ("files");

        var dot = basename.last_index_of (".");
        var stem = dot > 0 ? basename.substring (0, dot) : basename;
        var ext = dot > 0 ? basename.substring (dot) : "";

        var candidate = files_dir.get_child (basename);
        for (int i = 1; candidate.query_exists (cancellable); i++) {
            candidate = files_dir.get_child ("%s_%d%s".printf (stem, i, ext));
        }
        return candidate;
    }

    private async void write_trashinfo (string trashed_basename, File original, Cancellable cancellable) throws Error {
        var now = new DateTime.now_local ();
        var contents = "[Trash Info]\nPath=%s\nDeletionDate=%s\n".printf (
            Uri.escape_string (original.get_parse_name (), "/", false),
            now.format ("%Y-%m-%dT%H:%M:%S")
        );

        var info_file = trash_dir.get_child ("info").get_child (trashed_basename + ".trashinfo");
        yield info_file.replace_contents_async (
            contents.data,
            null,
            false,
            FileCreateFlags.NONE,
            cancellable,
            null
        );
    }
}
