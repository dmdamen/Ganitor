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

void test_candidate_file_path_falls_back_when_file_has_no_native_path () {
    // Gio.File.get_path() returns null for some backends (confirmed for at
    // least one Flatpak document-portal case); .path must never surface
    // that null, since callers use it for display without a null check.
    var file = File.new_for_uri ("dummy-scheme://host/some-path");
    assert (file.get_path () == null);

    var info = new FileInfo ();
    info.set_size (5);
    info.set_modification_date_time (new DateTime.now_utc ());
    var candidate = new Ganitor.CandidateFile (file, info);

    assert (candidate.path != null);
    assert (candidate.path == file.get_parse_name ());
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/candidate-file/basic", test_candidate_file_basic);
    Test.add_func ("/candidate-file/selected-is-mutable", test_candidate_file_selected_is_mutable);
    Test.add_func ("/candidate-file/path-falls-back-when-file-has-no-native-path", test_candidate_file_path_falls_back_when_file_has_no_native_path);
    return Test.run ();
}
