void test_format_button_label_is_always_clean () {
    // The button's label is a fixed action verb regardless of selection
    // state; the count/size detail belongs only in the confirmation dialog
    // shown before anything is actually trashed.
    assert (Ganitor.Format.button_label () == "Clean");
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/format/button-label/is-always-clean", test_format_button_label_is_always_clean);
    return Test.run ();
}
