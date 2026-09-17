using GanitorTest;

void test_candidate_file_basic () {
    var dir = make_fixture_dir ();
    var file = make_fixture_file (dir, "a.txt", "hello");
    var candidate = new Ganitor.CandidateFile (file, query_info_or_die (file));

    assert (candidate.path == file.get_path ());
    assert (candidate.size == 5);
    assert (candidate.selected == false);
    assert (candidate.checksum == null);
    assert (candidate.modified_time != null);

    remove_fixture_dir_recursive (dir);
}

void test_candidate_file_selected_is_mutable () {
    var dir = make_fixture_dir ();
    var file = make_fixture_file (dir, "b.txt", "x");
    var candidate = new Ganitor.CandidateFile (file, query_info_or_die (file));

    candidate.selected = true;
    assert (candidate.selected == true);

    candidate.checksum = "deadbeef";
    assert (candidate.checksum == "deadbeef");

    remove_fixture_dir_recursive (dir);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/candidate-file/basic", test_candidate_file_basic);
    Test.add_func ("/candidate-file/selected-is-mutable", test_candidate_file_selected_is_mutable);
    return Test.run ();
}
