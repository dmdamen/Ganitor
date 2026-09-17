namespace GanitorTest {
    public File make_fixture_file (string dir, string name, string content) {
        var path = Path.build_filename (dir, name);
        try {
            FileUtils.set_contents (path, content);
        } catch (FileError e) {
            error ("failed to write fixture file: %s", e.message);
        }
        return File.new_for_path (path);
    }

    public string make_fixture_dir () {
        try {
            return DirUtils.make_tmp ("ganitor-test-XXXXXX");
        } catch (FileError e) {
            error ("failed to create temp dir: %s", e.message);
        }
    }

    // GIO refuses to trash files on "system internal mounts" such as /tmp, so
    // tests that exercise the real trash_async() I/O need a fixture rooted
    // under $HOME instead of the usual DirUtils.make_tmp() location.
    public string make_home_fixture_dir () {
        var path = Path.build_filename (
            Environment.get_home_dir (),
            ".ganitor-test-%08x".printf (Random.next_int ())
        );
        DirUtils.create (path, 0700);
        return path;
    }

    public FileInfo query_info_or_die (File file) {
        try {
            return file.query_info (
                "standard::size,time::modified",
                FileQueryInfoFlags.NONE
            );
        } catch (Error e) {
            error ("failed to query info: %s", e.message);
        }
    }

    public Ganitor.CandidateFile make_candidate (string dir, string name, string content) {
        var file = make_fixture_file (dir, name, content);
        return new Ganitor.CandidateFile (file, query_info_or_die (file));
    }

    // Builds a FileInfo with a caller-chosen modified time rather than the
    // real filesystem mtime, so tests of mtime-dependent logic (like
    // auto-selecting the oldest duplicate) are deterministic instead of
    // depending on how fast fixture files were written on disk.
    public Ganitor.CandidateFile make_candidate_with_mtime (string dir, string name, string content, DateTime mtime) {
        var file = make_fixture_file (dir, name, content);
        var info = query_info_or_die (file);
        info.set_modification_date_time (mtime);
        return new Ganitor.CandidateFile (file, info);
    }

    public void remove_fixture_dir_recursive (string dir_path) {
        var dir = File.new_for_path (dir_path);
        try {
            var enumerator = dir.enumerate_children (
                "standard::name,standard::type",
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS
            );
            FileInfo? info;
            while ((info = enumerator.next_file ()) != null) {
                var child_path = Path.build_filename (dir_path, info.get_name ());
                if (info.get_file_type () == FileType.DIRECTORY) {
                    remove_fixture_dir_recursive (child_path);
                } else {
                    FileUtils.remove (child_path);
                }
            }
        } catch (Error e) {
            error ("failed to enumerate fixture dir: %s", e.message);
        }
        DirUtils.remove (dir_path);
    }
}
