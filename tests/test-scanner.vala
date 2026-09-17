using GanitorTest;

Ganitor.DuplicateScanner run_scan_sync (File root) {
    var scanner = new Ganitor.DuplicateScanner ();
    var loop = new MainLoop ();
    scanner.completed.connect (() => loop.quit ());
    scanner.run.begin (root, new Cancellable ());
    loop.run ();
    return scanner;
}

void test_scanner_groups_files_by_size_and_drops_singletons () {
    var dir = make_fixture_dir ();
    make_fixture_file (dir, "a.txt", "hello");
    make_fixture_file (dir, "b.txt", "hello");
    make_fixture_file (dir, "unique.txt", "unique content, no match");

    var scanner = run_scan_sync (File.new_for_path (dir));

    assert (scanner.groups.get_n_items () == 1);
    var group = (Ganitor.DuplicateGroup) scanner.groups.get_item (0);
    assert (group.files.get_n_items () == 2);
    assert (group.size == 5);

    remove_fixture_dir_recursive (dir);
}

void test_scanner_same_size_different_content_is_not_a_duplicate () {
    var dir = make_fixture_dir ();
    make_fixture_file (dir, "a.txt", "AAAAA");
    make_fixture_file (dir, "b.txt", "BBBBB");

    var scanner = run_scan_sync (File.new_for_path (dir));

    assert (scanner.groups.get_n_items () == 0);

    remove_fixture_dir_recursive (dir);
}

void test_scanner_recurses_into_subdirectories () {
    var dir = make_fixture_dir ();
    var subdir = Path.build_filename (dir, "sub");
    DirUtils.create (subdir, 0755);
    make_fixture_file (dir, "a.txt", "hello");
    make_fixture_file (subdir, "b.txt", "hello");

    var scanner = run_scan_sync (File.new_for_path (dir));

    assert (scanner.groups.get_n_items () == 1);
    var group = (Ganitor.DuplicateGroup) scanner.groups.get_item (0);
    assert (group.files.get_n_items () == 2);

    remove_fixture_dir_recursive (dir);
}

void test_scanner_excludes_zero_byte_files () {
    var dir = make_fixture_dir ();
    make_fixture_file (dir, "empty1.txt", "");
    make_fixture_file (dir, "empty2.txt", "");

    var scanner = run_scan_sync (File.new_for_path (dir));

    assert (scanner.groups.get_n_items () == 0);

    remove_fixture_dir_recursive (dir);
}

void test_scanner_reports_error_for_unreadable_subdirectory_but_completes () {
    var dir = make_fixture_dir ();
    make_fixture_file (dir, "a.txt", "hello");
    make_fixture_file (dir, "b.txt", "hello");

    var locked_dir = Path.build_filename (dir, "locked");
    DirUtils.create (locked_dir, 0755);
    make_fixture_file (locked_dir, "c.txt", "secret");
    FileUtils.chmod (locked_dir, 0000);

    uint error_count = 0;
    var scanner = new Ganitor.DuplicateScanner ();
    scanner.error_occurred.connect (() => error_count++);
    var loop = new MainLoop ();
    scanner.completed.connect (() => loop.quit ());
    scanner.run.begin (File.new_for_path (dir), new Cancellable ());
    loop.run ();

    assert (error_count >= 1);
    assert (scanner.groups.get_n_items () == 1);

    FileUtils.chmod (locked_dir, 0755);
    remove_fixture_dir_recursive (dir);
}

void test_scanner_cancellation_before_start_reports_cancelled_not_completed () {
    var dir = make_fixture_dir ();
    make_fixture_file (dir, "a.txt", "hello");

    var scanner = new Ganitor.DuplicateScanner ();
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

void test_scanner_cancellation_during_hashing_reports_cancelled () {
    var dir = make_fixture_dir ();
    make_fixture_file (dir, "a.txt", "hello");
    make_fixture_file (dir, "b.txt", "hello");

    var scanner = new Ganitor.DuplicateScanner ();
    var cancellable = new Cancellable ();

    scanner.progress.connect ((phase, current, total) => {
        if (phase == Ganitor.ScanPhase.HASHING) {
            cancellable.cancel ();
        }
    });

    bool cancelled_fired = false;
    var loop = new MainLoop ();
    scanner.cancelled.connect (() => { cancelled_fired = true; loop.quit (); });
    scanner.completed.connect (() => loop.quit ());

    scanner.run.begin (File.new_for_path (dir), cancellable);
    loop.run ();

    assert (cancelled_fired == true);

    remove_fixture_dir_recursive (dir);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/scanner/groups-by-size-and-drops-singletons", test_scanner_groups_files_by_size_and_drops_singletons);
    Test.add_func ("/scanner/same-size-different-content-is-not-a-duplicate", test_scanner_same_size_different_content_is_not_a_duplicate);
    Test.add_func ("/scanner/recurses-into-subdirectories", test_scanner_recurses_into_subdirectories);
    Test.add_func ("/scanner/excludes-zero-byte-files", test_scanner_excludes_zero_byte_files);
    Test.add_func ("/scanner/reports-error-for-unreadable-subdirectory-but-completes", test_scanner_reports_error_for_unreadable_subdirectory_but_completes);
    Test.add_func ("/scanner/cancellation-before-start-reports-cancelled-not-completed", test_scanner_cancellation_before_start_reports_cancelled_not_completed);
    Test.add_func ("/scanner/cancellation-during-hashing-reports-cancelled", test_scanner_cancellation_during_hashing_reports_cancelled);
    return Test.run ();
}
