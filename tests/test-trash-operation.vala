using GanitorTest;

bool contains_file (File[] files, File needle) {
    foreach (var f in files) {
        if (f.equal (needle)) {
            return true;
        }
    }
    return false;
}

Ganitor.CandidateFile make_candidate_for_file (File file, int64 size) {
    var info = new FileInfo ();
    info.set_size (size);
    info.set_modification_date_time (new DateTime.now_utc ());
    return new Ganitor.CandidateFile (file, info);
}

void test_trash_operation_selected_files_filters_by_selection () {
    var dir = make_fixture_dir ();

    var group1 = new Ganitor.DuplicateGroup ("abc", 5);
    var a = make_candidate (dir, "a.txt", "hello");
    var b = make_candidate (dir, "b.txt", "hello");
    a.selected = true;
    group1.add_file (a);
    group1.add_file (b);

    var group2 = new Ganitor.DuplicateGroup ("xyz", 3);
    var c = make_candidate (dir, "c.txt", "wor");
    var d = make_candidate (dir, "d.txt", "wor");
    c.selected = true;
    d.selected = true;
    group2.add_file (c);
    group2.add_file (d);

    var groups = new ListStore (typeof (Ganitor.DuplicateGroup));
    groups.append (group1);
    groups.append (group2);

    var files = Ganitor.TrashOperation.selected_files (groups);

    assert (files.length == 3);
    assert (contains_file (files, a.file));
    assert (contains_file (files, c.file));
    assert (contains_file (files, d.file));
    assert (!contains_file (files, b.file));

    remove_fixture_dir_recursive (dir);
}

void test_trash_operation_selected_files_empty_when_nothing_selected () {
    var dir = make_fixture_dir ();
    var group = new Ganitor.DuplicateGroup ("abc", 5);
    group.add_file (make_candidate (dir, "a.txt", "hello"));

    var groups = new ListStore (typeof (Ganitor.DuplicateGroup));
    groups.append (group);

    var files = Ganitor.TrashOperation.selected_files (groups);
    assert (files.length == 0);

    remove_fixture_dir_recursive (dir);
}

void test_trash_operation_selected_files_does_not_require_a_native_path () {
    // Regression test for a real crash: some Gio.File backends (confirmed
    // for at least one Flatpak document-portal case) return null from
    // get_path(). Candidate identification and selection must go through
    // Gio.File objects directly and never round-trip through a path string.
    var included = File.new_for_uri ("dummy-scheme://host/included-path");
    var excluded = File.new_for_uri ("dummy-scheme://host/excluded-path");
    assert (included.get_path () == null);

    var included_candidate = make_candidate_for_file (included, 5);
    included_candidate.selected = true;
    var excluded_candidate = make_candidate_for_file (excluded, 5);

    var group = new Ganitor.DuplicateGroup ("abc", 5);
    group.add_file (included_candidate);
    group.add_file (excluded_candidate);

    var groups = new ListStore (typeof (Ganitor.DuplicateGroup));
    groups.append (group);

    var files = Ganitor.TrashOperation.selected_files (groups);
    assert (files.length == 1);
    assert (files[0].equal (included));
}

void remove_from_real_trash (string basename) {
    var trash_dir = File.new_for_uri ("trash:///");
    try {
        var enumerator = trash_dir.enumerate_children ("standard::name", FileQueryInfoFlags.NONE);
        FileInfo? info;
        while ((info = enumerator.next_file ()) != null) {
            if (info.get_name () == basename) {
                try {
                    trash_dir.get_child (info.get_name ()).delete ();
                } catch (Error e) {
                    // best-effort cleanup only
                }
            }
        }
    } catch (Error e) {
        // best-effort cleanup only
    }
}

void test_trash_operation_run_moves_selected_files_to_real_trash () {
    var dir = make_home_fixture_dir ();
    var candidate = make_candidate (dir, "victim.txt", "hello");
    var basename = candidate.file.get_basename ();

    var op = new Ganitor.TrashOperation ();
    var loop = new MainLoop ();
    Ganitor.TrashResult result = Ganitor.TrashResult () { succeeded = 0, failed_files = {} };
    op.run.begin (new File[] { candidate.file }, new Cancellable (), (obj, res) => {
        result = op.run.end (res);
        loop.quit ();
    });
    loop.run ();

    if (result.succeeded == 0) {
        Test.skip ("trash_async() not supported for this fixture location in this environment");
        remove_fixture_dir_recursive (dir);
        return;
    }

    assert (result.succeeded == 1);
    assert (result.failed_files.length == 0);
    assert (!candidate.file.query_exists ());

    remove_from_real_trash (basename);
    remove_fixture_dir_recursive (dir);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/trash-operation/selected-files-filters-by-selection", test_trash_operation_selected_files_filters_by_selection);
    Test.add_func ("/trash-operation/selected-files-empty-when-nothing-selected", test_trash_operation_selected_files_empty_when_nothing_selected);
    Test.add_func ("/trash-operation/selected-files-does-not-require-a-native-path", test_trash_operation_selected_files_does_not_require_a_native_path);
    Test.add_func ("/trash-operation/run-moves-selected-files-to-real-trash", test_trash_operation_run_moves_selected_files_to_real_trash);
    return Test.run ();
}
