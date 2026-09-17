using GanitorTest;

Ganitor.EmptyFolderScanner run_scan_sync (File root) {
    var scanner = new Ganitor.EmptyFolderScanner ();
    var loop = new MainLoop ();
    scanner.completed.connect (() => loop.quit ());
    scanner.run.begin (root, new Cancellable ());
    loop.run ();
    return scanner;
}

bool contains_path (ListStore folders, string path) {
    for (uint i = 0; i < folders.get_n_items (); i++) {
        var folder = (Ganitor.EmptyFolder) folders.get_item (i);
        if (folder.file.get_path () == path) {
            return true;
        }
    }
    return false;
}

void test_empty_folder_scanner_finds_a_single_empty_folder () {
    var dir = make_fixture_dir ();
    var empty_dir = Path.build_filename (dir, "empty");
    DirUtils.create (empty_dir, 0755);

    var scanner = run_scan_sync (File.new_for_path (dir));

    assert (scanner.folders.get_n_items () == 1);
    assert (contains_path (scanner.folders, empty_dir));

    remove_fixture_dir_recursive (dir);
}

void test_empty_folder_scanner_excludes_folder_containing_a_file () {
    var dir = make_fixture_dir ();
    var not_empty = Path.build_filename (dir, "not-empty");
    DirUtils.create (not_empty, 0755);
    make_fixture_file (not_empty, "a.txt", "hello");

    var scanner = run_scan_sync (File.new_for_path (dir));

    assert (scanner.folders.get_n_items () == 0);

    remove_fixture_dir_recursive (dir);
}

void test_empty_folder_scanner_offers_only_the_topmost_of_a_nested_empty_chain () {
    var dir = make_fixture_dir ();
    var a = Path.build_filename (dir, "a");
    var b = Path.build_filename (a, "b");
    var c = Path.build_filename (b, "c");
    DirUtils.create_with_parents (c, 0755);

    var scanner = run_scan_sync (File.new_for_path (dir));

    assert (scanner.folders.get_n_items () == 1);
    assert (contains_path (scanner.folders, a));

    remove_fixture_dir_recursive (dir);
}

void test_empty_folder_scanner_finds_multiple_independent_empty_folders () {
    var dir = make_fixture_dir ();
    var empty1 = Path.build_filename (dir, "empty1");
    var empty2 = Path.build_filename (dir, "empty2");
    var not_empty = Path.build_filename (dir, "not-empty");
    DirUtils.create (empty1, 0755);
    DirUtils.create (empty2, 0755);
    DirUtils.create (not_empty, 0755);
    make_fixture_file (not_empty, "a.txt", "hello");

    var scanner = run_scan_sync (File.new_for_path (dir));

    assert (scanner.folders.get_n_items () == 2);
    assert (contains_path (scanner.folders, empty1));
    assert (contains_path (scanner.folders, empty2));

    remove_fixture_dir_recursive (dir);
}

void test_empty_folder_scanner_finds_empty_folder_nested_inside_a_kept_folder () {
    var dir = make_fixture_dir ();
    var keep = Path.build_filename (dir, "keep");
    var empty_child = Path.build_filename (keep, "empty-child");
    DirUtils.create_with_parents (empty_child, 0755);
    make_fixture_file (keep, "a.txt", "hello");

    var scanner = run_scan_sync (File.new_for_path (dir));

    assert (scanner.folders.get_n_items () == 1);
    assert (contains_path (scanner.folders, empty_child));

    remove_fixture_dir_recursive (dir);
}

void test_empty_folder_scanner_never_offers_the_scan_root_itself () {
    // The whole tree under `dir` is empty (only a nested empty subdirectory),
    // so `dir` itself technically qualifies too - but removing the folder
    // the user explicitly chose to scan would be surprising, so only its
    // subdirectory should be offered.
    var dir = make_fixture_dir ();
    var only_child = Path.build_filename (dir, "only-child");
    DirUtils.create (only_child, 0755);

    var scanner = run_scan_sync (File.new_for_path (dir));

    assert (scanner.folders.get_n_items () == 1);
    assert (contains_path (scanner.folders, only_child));

    remove_fixture_dir_recursive (dir);
}

void test_empty_folder_scanner_finds_nothing_when_scan_root_has_no_subdirectories () {
    var dir = make_fixture_dir ();
    make_fixture_file (dir, "a.txt", "hello");

    var scanner = run_scan_sync (File.new_for_path (dir));

    assert (scanner.folders.get_n_items () == 0);

    remove_fixture_dir_recursive (dir);
}

void test_empty_folder_scanner_select_all_marks_every_folder_selected () {
    var dir = make_fixture_dir ();
    DirUtils.create (Path.build_filename (dir, "empty1"), 0755);
    DirUtils.create (Path.build_filename (dir, "empty2"), 0755);

    var scanner = run_scan_sync (File.new_for_path (dir));
    assert (scanner.folders.get_n_items () == 2);

    scanner.select_all ();

    for (uint i = 0; i < scanner.folders.get_n_items (); i++) {
        assert (((Ganitor.EmptyFolder) scanner.folders.get_item (i)).selected == true);
    }

    remove_fixture_dir_recursive (dir);
}

void test_empty_folder_scanner_reports_error_for_unreadable_subdirectory_but_completes () {
    var dir = make_fixture_dir ();
    var empty_dir = Path.build_filename (dir, "empty");
    DirUtils.create (empty_dir, 0755);

    var locked_dir = Path.build_filename (dir, "locked");
    DirUtils.create (locked_dir, 0755);
    make_fixture_file (locked_dir, "secret.txt", "x");
    FileUtils.chmod (locked_dir, 0000);

    uint error_count = 0;
    var scanner = new Ganitor.EmptyFolderScanner ();
    scanner.error_occurred.connect (() => error_count++);
    var loop = new MainLoop ();
    scanner.completed.connect (() => loop.quit ());
    scanner.run.begin (File.new_for_path (dir), new Cancellable ());
    loop.run ();

    assert (error_count >= 1);
    assert (contains_path (scanner.folders, empty_dir));

    FileUtils.chmod (locked_dir, 0755);
    remove_fixture_dir_recursive (dir);
}

void test_empty_folder_scanner_cancellation_reports_cancelled_not_completed () {
    var dir = make_fixture_dir ();
    DirUtils.create (Path.build_filename (dir, "empty"), 0755);

    var scanner = new Ganitor.EmptyFolderScanner ();
    var cancellable = new Cancellable ();
    cancellable.cancel ();

    bool cancelled_fired = false;
    bool completed_fired = false;
    var loop = new MainLoop ();
    scanner.cancelled.connect (() => { cancelled_fired = true; loop.quit (); });
    scanner.completed.connect (() => { completed_fired = true; loop.quit (); });

    scanner.run.begin (File.new_for_path (dir), cancellable);
    loop.run ();

    assert (cancelled_fired == true);
    assert (completed_fired == false);

    remove_fixture_dir_recursive (dir);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/empty-folder-scanner/finds-a-single-empty-folder", test_empty_folder_scanner_finds_a_single_empty_folder);
    Test.add_func ("/empty-folder-scanner/excludes-folder-containing-a-file", test_empty_folder_scanner_excludes_folder_containing_a_file);
    Test.add_func ("/empty-folder-scanner/offers-only-the-topmost-of-a-nested-empty-chain", test_empty_folder_scanner_offers_only_the_topmost_of_a_nested_empty_chain);
    Test.add_func ("/empty-folder-scanner/finds-multiple-independent-empty-folders", test_empty_folder_scanner_finds_multiple_independent_empty_folders);
    Test.add_func ("/empty-folder-scanner/finds-empty-folder-nested-inside-a-kept-folder", test_empty_folder_scanner_finds_empty_folder_nested_inside_a_kept_folder);
    Test.add_func ("/empty-folder-scanner/never-offers-the-scan-root-itself", test_empty_folder_scanner_never_offers_the_scan_root_itself);
    Test.add_func ("/empty-folder-scanner/finds-nothing-when-scan-root-has-no-subdirectories", test_empty_folder_scanner_finds_nothing_when_scan_root_has_no_subdirectories);
    Test.add_func ("/empty-folder-scanner/select-all-marks-every-folder-selected", test_empty_folder_scanner_select_all_marks_every_folder_selected);
    Test.add_func ("/empty-folder-scanner/reports-error-for-unreadable-subdirectory-but-completes", test_empty_folder_scanner_reports_error_for_unreadable_subdirectory_but_completes);
    Test.add_func ("/empty-folder-scanner/cancellation-reports-cancelled-not-completed", test_empty_folder_scanner_cancellation_reports_cancelled_not_completed);
    return Test.run ();
}
