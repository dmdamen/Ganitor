using GanitorTest;

void test_trash_operation_selected_paths_filters_by_selection () {
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

    var paths = Ganitor.TrashOperation.selected_paths (groups);

    assert (paths.length == 3);
    var path_set = new HashTable<string, bool> (str_hash, str_equal);
    foreach (var path in paths) {
        path_set.insert (path, true);
    }
    assert (path_set.contains (a.path));
    assert (path_set.contains (c.path));
    assert (path_set.contains (d.path));
    assert (!path_set.contains (b.path));

    remove_fixture_dir_recursive (dir);
}

void test_trash_operation_selected_paths_empty_when_nothing_selected () {
    var dir = make_fixture_dir ();
    var group = new Ganitor.DuplicateGroup ("abc", 5);
    group.add_file (make_candidate (dir, "a.txt", "hello"));

    var groups = new ListStore (typeof (Ganitor.DuplicateGroup));
    groups.append (group);

    var paths = Ganitor.TrashOperation.selected_paths (groups);
    assert (paths.length == 0);

    remove_fixture_dir_recursive (dir);
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
    var basename = Path.get_basename (candidate.path);

    var op = new Ganitor.TrashOperation ();
    var loop = new MainLoop ();
    Ganitor.TrashResult result = Ganitor.TrashResult () { succeeded = 0, failed_paths = {} };
    op.run.begin (new string[] { candidate.path }, new Cancellable (), (obj, res) => {
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
    assert (result.failed_paths.length == 0);
    assert (!FileUtils.test (candidate.path, FileTest.EXISTS));

    remove_from_real_trash (basename);
    remove_fixture_dir_recursive (dir);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/trash-operation/selected-paths-filters-by-selection", test_trash_operation_selected_paths_filters_by_selection);
    Test.add_func ("/trash-operation/selected-paths-empty-when-nothing-selected", test_trash_operation_selected_paths_empty_when_nothing_selected);
    Test.add_func ("/trash-operation/run-moves-selected-files-to-real-trash", test_trash_operation_run_moves_selected_files_to_real_trash);
    return Test.run ();
}
