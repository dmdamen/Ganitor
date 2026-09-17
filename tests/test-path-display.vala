using GanitorTest;

void test_path_display_relative_path_for_nested_file () {
    var root = File.new_for_path ("/scan/root");
    var target = File.new_for_path ("/scan/root/Videos/2019/clip.mp4");

    assert (Ganitor.PathDisplay.relative_path (root, target) == "Videos/2019/clip.mp4");
}

void test_path_display_relative_path_for_direct_child () {
    var root = File.new_for_path ("/scan/root");
    var target = File.new_for_path ("/scan/root/photo.jpg");

    assert (Ganitor.PathDisplay.relative_path (root, target) == "photo.jpg");
}

void test_path_display_relative_parent_directory_for_nested_file () {
    var root = File.new_for_path ("/scan/root");
    var target = File.new_for_path ("/scan/root/Videos/2019/clip.mp4");

    assert (Ganitor.PathDisplay.relative_parent_directory (root, target) == "Videos/2019");
}

void test_path_display_relative_parent_directory_for_direct_child () {
    // A file directly in the scanned root has no relative parent to show,
    // so this falls back to the root folder's own display name.
    var root = File.new_for_path ("/scan/root");
    var target = File.new_for_path ("/scan/root/photo.jpg");

    assert (Ganitor.PathDisplay.relative_parent_directory (root, target) == "root");
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/path-display/relative-path-for-nested-file", test_path_display_relative_path_for_nested_file);
    Test.add_func ("/path-display/relative-path-for-direct-child", test_path_display_relative_path_for_direct_child);
    Test.add_func ("/path-display/relative-parent-directory-for-nested-file", test_path_display_relative_parent_directory_for_nested_file);
    Test.add_func ("/path-display/relative-parent-directory-for-direct-child", test_path_display_relative_parent_directory_for_direct_child);
    return Test.run ();
}
