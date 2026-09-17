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

void test_trash_operation_selected_folders_filters_by_selection () {
    var included = new Ganitor.EmptyFolder (File.new_for_path ("/scan/root/included"));
    var excluded = new Ganitor.EmptyFolder (File.new_for_path ("/scan/root/excluded"));
    included.selected = true;

    var folders = new ListStore (typeof (Ganitor.EmptyFolder));
    folders.append (included);
    folders.append (excluded);

    var files = Ganitor.TrashOperation.selected_folders (folders);

    assert (files.length == 1);
    assert (files[0].equal (included.file));
}

void test_trash_operation_selected_folders_empty_when_nothing_selected () {
    var folders = new ListStore (typeof (Ganitor.EmptyFolder));
    folders.append (new Ganitor.EmptyFolder (File.new_for_path ("/scan/root/a")));

    var files = Ganitor.TrashOperation.selected_folders (folders);
    assert (files.length == 0);
}

Ganitor.TrashResult run_trash_sync (Ganitor.TrashOperation op, File[] files) {
    var loop = new MainLoop ();
    Ganitor.TrashResult result = Ganitor.TrashResult () { succeeded_files = {}, failed_files = {} };
    op.run.begin (files, new Cancellable (), (obj, res) => {
        result = op.run.end (res);
        loop.quit ();
    });
    loop.run ();
    return result;
}

string read_file_contents (File file) {
    try {
        uint8[] contents;
        file.load_contents (null, out contents, null);
        return (string) contents;
    } catch (Error e) {
        error ("failed to read %s: %s", file.get_path (), e.message);
    }
}

// Ganitor never gets a real host path for scanned files under the
// portal-only sandbox (Gio.File.trash_async() hard-refuses to trash
// anything on the document-portal's FUSE mount - confirmed via a real
// crash investigation), so trashing is implemented manually: copy the
// file into a Trash directory, write .trashinfo, then delete the
// original. These tests inject a scratch directory as that Trash
// directory instead of touching the real ~/.local/share/Trash.

void test_trash_operation_run_copies_into_trash_and_writes_trashinfo () {
    var source_dir = make_fixture_dir ();
    var trash_root = make_fixture_dir ();
    var trash_dir = File.new_for_path (Path.build_filename (trash_root, "Trash"));

    var source_file = make_fixture_file (source_dir, "victim.txt", "hello world");

    var op = new Ganitor.TrashOperation (trash_dir);
    var result = run_trash_sync (op, new File[] { source_file });

    assert (result.succeeded_files.length == 1);
    assert (result.failed_files.length == 0);
    assert (!source_file.query_exists ());

    var trashed_file = trash_dir.get_child ("files").get_child ("victim.txt");
    assert (trashed_file.query_exists ());
    assert (read_file_contents (trashed_file) == "hello world");

    var trashinfo = trash_dir.get_child ("info").get_child ("victim.txt.trashinfo");
    assert (trashinfo.query_exists ());
    var trashinfo_content = read_file_contents (trashinfo);
    assert (trashinfo_content.contains ("[Trash Info]"));
    assert (trashinfo_content.contains ("DeletionDate="));

    remove_fixture_dir_recursive (source_dir);
    remove_fixture_dir_recursive (trash_root);
}

void test_trash_operation_run_resolves_filename_collisions () {
    var trash_root = make_fixture_dir ();
    var trash_dir = File.new_for_path (Path.build_filename (trash_root, "Trash"));

    var dir1 = make_fixture_dir ();
    var dir2 = make_fixture_dir ();
    var file1 = make_fixture_file (dir1, "dup.txt", "one");
    var file2 = make_fixture_file (dir2, "dup.txt", "two");

    var op = new Ganitor.TrashOperation (trash_dir);
    var result = run_trash_sync (op, new File[] { file1, file2 });

    assert (result.succeeded_files.length == 2);
    assert (result.failed_files.length == 0);

    var files_dir = trash_dir.get_child ("files");
    var first = files_dir.get_child ("dup.txt");
    var second = files_dir.get_child ("dup_1.txt");
    assert (first.query_exists ());
    assert (second.query_exists ());
    assert (read_file_contents (first) == "one");
    assert (read_file_contents (second) == "two");
    assert (trash_dir.get_child ("info").get_child ("dup.txt.trashinfo").query_exists ());
    assert (trash_dir.get_child ("info").get_child ("dup_1.txt.trashinfo").query_exists ());

    remove_fixture_dir_recursive (dir1);
    remove_fixture_dir_recursive (dir2);
    remove_fixture_dir_recursive (trash_root);
}

void test_trash_operation_run_moves_an_empty_folder_into_trash () {
    var source_root = make_fixture_dir ();
    var empty_folder = Path.build_filename (source_root, "empty");
    DirUtils.create (empty_folder, 0755);
    var folder_file = File.new_for_path (empty_folder);

    var trash_root = make_fixture_dir ();
    var trash_dir = File.new_for_path (Path.build_filename (trash_root, "Trash"));

    var op = new Ganitor.TrashOperation (trash_dir);
    var result = run_trash_sync (op, new File[] { folder_file });

    assert (result.succeeded_files.length == 1);
    assert (result.failed_files.length == 0);
    assert (!folder_file.query_exists ());

    var trashed = trash_dir.get_child ("files").get_child ("empty");
    assert (trashed.query_exists ());
    assert (trashed.query_file_type (FileQueryInfoFlags.NONE) == FileType.DIRECTORY);
    assert (trash_dir.get_child ("info").get_child ("empty.trashinfo").query_exists ());

    remove_fixture_dir_recursive (source_root);
    remove_fixture_dir_recursive (trash_root);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/trash-operation/selected-files-filters-by-selection", test_trash_operation_selected_files_filters_by_selection);
    Test.add_func ("/trash-operation/selected-files-empty-when-nothing-selected", test_trash_operation_selected_files_empty_when_nothing_selected);
    Test.add_func ("/trash-operation/selected-files-does-not-require-a-native-path", test_trash_operation_selected_files_does_not_require_a_native_path);
    Test.add_func ("/trash-operation/selected-folders-filters-by-selection", test_trash_operation_selected_folders_filters_by_selection);
    Test.add_func ("/trash-operation/selected-folders-empty-when-nothing-selected", test_trash_operation_selected_folders_empty_when_nothing_selected);
    Test.add_func ("/trash-operation/run-copies-into-trash-and-writes-trashinfo", test_trash_operation_run_copies_into_trash_and_writes_trashinfo);
    Test.add_func ("/trash-operation/run-resolves-filename-collisions", test_trash_operation_run_resolves_filename_collisions);
    Test.add_func ("/trash-operation/run-moves-an-empty-folder-into-trash", test_trash_operation_run_moves_an_empty_folder_into_trash);
    return Test.run ();
}
