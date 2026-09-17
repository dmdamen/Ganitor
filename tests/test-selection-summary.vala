using GanitorTest;

void test_selection_summary_empty () {
    var groups = new ListStore (typeof (Ganitor.DuplicateGroup));
    var summary = Ganitor.SelectionSummary.compute (groups);
    assert (summary.count == 0);
    assert (summary.bytes == 0);
}

void test_selection_summary_no_files_selected () {
    var dir = make_fixture_dir ();
    var group = new Ganitor.DuplicateGroup ("abc", 5);
    group.add_file (make_candidate (dir, "a.txt", "hello"));
    group.add_file (make_candidate (dir, "b.txt", "hello"));

    var groups = new ListStore (typeof (Ganitor.DuplicateGroup));
    groups.append (group);

    var summary = Ganitor.SelectionSummary.compute (groups);
    assert (summary.count == 0);
    assert (summary.bytes == 0);

    remove_fixture_dir_recursive (dir);
}

void test_selection_summary_mixed_selection_across_groups () {
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

    var summary = Ganitor.SelectionSummary.compute (groups);
    assert (summary.count == 3);
    assert (summary.bytes == 5 + 3 + 3);

    remove_fixture_dir_recursive (dir);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/selection-summary/empty", test_selection_summary_empty);
    Test.add_func ("/selection-summary/no-files-selected", test_selection_summary_no_files_selected);
    Test.add_func ("/selection-summary/mixed-selection-across-groups", test_selection_summary_mixed_selection_across_groups);
    return Test.run ();
}
