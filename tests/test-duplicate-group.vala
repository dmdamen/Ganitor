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

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/duplicate-group/add-file", test_duplicate_group_add_file);
    Test.add_func ("/duplicate-group/wasted-bytes", test_duplicate_group_wasted_bytes);
    return Test.run ();
}
