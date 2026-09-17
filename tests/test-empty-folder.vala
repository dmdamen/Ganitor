using GanitorTest;

void test_empty_folder_basic () {
    var dir = make_fixture_dir ();
    var folder = new Ganitor.EmptyFolder (File.new_for_path (dir));

    assert (folder.file.get_path () == dir);
    assert (folder.selected == false);

    remove_fixture_dir_recursive (dir);
}

void test_empty_folder_selected_is_mutable () {
    var dir = make_fixture_dir ();
    var folder = new Ganitor.EmptyFolder (File.new_for_path (dir));

    folder.selected = true;
    assert (folder.selected == true);

    remove_fixture_dir_recursive (dir);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/empty-folder/basic", test_empty_folder_basic);
    Test.add_func ("/empty-folder/selected-is-mutable", test_empty_folder_selected_is_mutable);
    return Test.run ();
}
