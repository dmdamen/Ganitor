void test_format_button_label_no_selection () {
    var summary = Ganitor.Summary () { count = 0, bytes = 0 };
    assert (Ganitor.Format.button_label (summary) == "Move to Trash");
}

void test_format_button_label_singular () {
    var summary = Ganitor.Summary () { count = 1, bytes = 1024 };
    var expected = "Move 1 File to Trash (%s)".printf (GLib.format_size (summary.bytes));
    assert (Ganitor.Format.button_label (summary) == expected);
}

void test_format_button_label_plural () {
    var summary = Ganitor.Summary () { count = 3, bytes = 12400000 };
    var expected = "Move %u Files to Trash (%s)".printf (summary.count, GLib.format_size (summary.bytes));
    assert (Ganitor.Format.button_label (summary) == expected);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/format/button-label/no-selection", test_format_button_label_no_selection);
    Test.add_func ("/format/button-label/singular", test_format_button_label_singular);
    Test.add_func ("/format/button-label/plural", test_format_button_label_plural);
    return Test.run ();
}
