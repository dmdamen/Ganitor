using GanitorTest;

void test_duplicate_group_add_file () {
    var group = new Ganitor.DuplicateGroup ("abc123", 5);
    var dir = make_fixture_dir ();

    group.add_file (make_candidate (dir, "a.txt", "hello"));
    group.add_file (make_candidate (dir, "b.txt", "hello"));

    assert (group.checksum == "abc123");
    assert (group.size == 5);
    assert (group.files.get_n_items () == 2);

    remove_fixture_dir_recursive (dir);
}

void test_duplicate_group_wasted_bytes () {
    var group = new Ganitor.DuplicateGroup ("abc123", 5);
    var dir = make_fixture_dir ();

    group.add_file (make_candidate (dir, "a.txt", "hello"));
    group.add_file (make_candidate (dir, "b.txt", "hello"));
    group.add_file (make_candidate (dir, "c.txt", "hello"));

    // 3 copies of a 5-byte file: 2 are redundant.
    assert (group.wasted_bytes == 10);

    remove_fixture_dir_recursive (dir);
}

void test_duplicate_group_auto_select_duplicates_keeps_oldest () {
    var group = new Ganitor.DuplicateGroup ("abc123", 5);
    var dir = make_fixture_dir ();
    var now = new DateTime.now_utc ();

    var oldest = make_candidate_with_mtime (dir, "old.txt", "hello", now.add_days (-2));
    var middle = make_candidate_with_mtime (dir, "mid.txt", "hello", now.add_days (-1));
    var newest = make_candidate_with_mtime (dir, "new.txt", "hello", now);

    // Added out of chronological order to prove the result doesn't depend
    // on insertion order, only on modified_time.
    group.add_file (middle);
    group.add_file (newest);
    group.add_file (oldest);

    group.auto_select_duplicates ();

    assert (oldest.selected == false);
    assert (middle.selected == true);
    assert (newest.selected == true);

    remove_fixture_dir_recursive (dir);
}

void test_duplicate_group_auto_select_duplicates_noop_for_single_file () {
    var group = new Ganitor.DuplicateGroup ("abc123", 5);
    var dir = make_fixture_dir ();

    var only = make_candidate (dir, "a.txt", "hello");
    group.add_file (only);

    group.auto_select_duplicates ();

    assert (only.selected == false);

    remove_fixture_dir_recursive (dir);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/duplicate-group/add-file", test_duplicate_group_add_file);
    Test.add_func ("/duplicate-group/wasted-bytes", test_duplicate_group_wasted_bytes);
    Test.add_func ("/duplicate-group/auto-select-duplicates-keeps-oldest", test_duplicate_group_auto_select_duplicates_keeps_oldest);
    Test.add_func ("/duplicate-group/auto-select-duplicates-noop-for-single-file", test_duplicate_group_auto_select_duplicates_noop_for_single_file);
    return Test.run ();
}
