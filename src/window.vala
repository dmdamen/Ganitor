// The cleanup flow is an ordered chain of steps sharing the same header-bar
// "Clean"/"Skip" buttons, the same scanning/results pages, and (for steps
// that remove things) the same trash mechanism: today, duplicate files then
// empty folders. Each step is its own self-contained set of methods
// (start_<step>_scan, on_<step>_scan_completed, update_<step>_*,
// on_trash_<step>_clicked, apply_<step>_trash_result) rather than a shared,
// branch-heavy dispatcher, since the steps' data shapes and actions don't
// actually line up closely enough to unify cleanly (and a later step -
// "organize files" - is expected to be a move/rename action rather than a
// select-and-remove one, which wouldn't fit this shape at all).
//
// Three distinct triggers all mean "I'm done with this step, move on": the
// step's scan finding nothing to do, the user cancelling the scan, and the
// user clicking the manual "Skip" button on a step's results. All three
// funnel into one function per step, finish_<step>_step(), which either
// starts the next step or - for the current last step - shows the terminal
// "All Clean" page. Reserved future order: duplicate files -> similar media
// -> organize files -> empty folders. Adding a step later should only ever
// require editing the immediately-preceding step's finish_<step>_step().
private enum Ganitor.CleanupStep {
    DUPLICATE_FILES,
    EMPTY_FOLDERS
}

[GtkTemplate (ui = "/io/github/dmdamen/Ganitor/window.ui")]
public class Ganitor.Window : Adw.ApplicationWindow {
    [GtkChild]
    private unowned Gtk.Button select_folder_button;
    [GtkChild]
    private unowned Gtk.Button trash_button;
    [GtkChild]
    private unowned Gtk.Button skip_button;
    [GtkChild]
    private unowned Adw.ToastOverlay toast_overlay;
    [GtkChild]
    private unowned Adw.ViewStack view_stack;
    [GtkChild]
    private unowned Adw.StatusPage scanning_page;
    [GtkChild]
    private unowned Gtk.ProgressBar progress_bar;
    [GtkChild]
    private unowned Gtk.Button cancel_scan_button;
    [GtkChild]
    private unowned Gtk.Label summary_label;
    [GtkChild]
    private unowned Gtk.ListBox groups_list;
    [GtkChild]
    private unowned Adw.StatusPage all_clean_page;
    [GtkChild]
    private unowned Adw.StatusPage error_page;

    private delegate void TrashCompletionHandler (owned TrashResult result);

    private Settings settings;
    private CleanupStep current_step;
    private DuplicateScanner? scanner;
    private EmptyFolderScanner? empty_folder_scanner;
    private File? current_scan_root;
    private Cancellable? scan_cancellable;
    private uint scan_error_count;
    private StringBuilder scan_error_text;

    public Window (Gtk.Application app) {
        Object (application: app);
    }

    construct {
        settings = new Settings (Config.APP_ID);

        default_width = settings.get_int ("window-width");
        default_height = settings.get_int ("window-height");
        if (settings.get_boolean ("window-maximized")) {
            maximize ();
        }
        close_request.connect (on_close_request);

        select_folder_button.clicked.connect (on_select_folder_clicked);
        trash_button.clicked.connect (on_trash_clicked);
        skip_button.clicked.connect (on_skip_clicked);
        cancel_scan_button.clicked.connect (on_cancel_clicked);
    }

    // Gtk.Window's default-width/height are construct-time hints, not
    // properties that track interactive resizes, so persisting the live
    // window size has to happen here rather than via Settings.bind().
    private bool on_close_request () {
        if (!maximized) {
            settings.set_int ("window-width", get_width ());
            settings.set_int ("window-height", get_height ());
        }
        settings.set_boolean ("window-maximized", maximized);
        return false;
    }

    private void on_select_folder_clicked () {
        var dialog = new Gtk.FileDialog () {
            title = "Select a Folder to Scan",
        };

        // Stored/restored as a URI, not a path: File.get_path() can be null
        // for some backends (e.g. certain Flatpak document-portal folders),
        // but get_uri()/new_for_uri() work for any Gio.File regardless of
        // backend.
        var last_folder = settings.get_string ("last-folder");
        if (last_folder != "") {
            var dir = File.new_for_uri (last_folder);
            if (dir.query_exists ()) {
                dialog.initial_folder = dir;
            }
        }

        dialog.select_folder.begin (this, null, (obj, res) => {
            File folder;
            try {
                folder = dialog.select_folder.end (res);
            } catch (Error e) {
                return;
            }

            settings.set_string ("last-folder", folder.get_uri ());
            current_scan_root = folder;
            start_duplicate_scan (folder);
        });
    }

    private void on_cancel_clicked () {
        if (scan_cancellable != null) {
            scan_cancellable.cancel ();
        }
    }

    private void on_trash_clicked () {
        switch (current_step) {
        case CleanupStep.DUPLICATE_FILES:
            on_trash_duplicate_clicked ();
            break;
        case CleanupStep.EMPTY_FOLDERS:
            on_trash_empty_folder_clicked ();
            break;
        }
    }

    private void on_skip_clicked () {
        switch (current_step) {
        case CleanupStep.DUPLICATE_FILES:
            finish_duplicate_step ();
            break;
        case CleanupStep.EMPTY_FOLDERS:
            finish_empty_folder_step ();
            break;
        }
    }

    private void reset_scan_errors () {
        scan_error_count = 0;
        scan_error_text = new StringBuilder ();
    }

    private void on_scan_error (File location, Error error) {
        scan_error_count++;
        scan_error_text.append_printf (
            "%s: %s\n",
            location.get_path () ?? location.get_uri (),
            error.message
        );
    }

    private void show_scan_error_page () {
        skip_button.visible = false;
        error_page.description = scan_error_text.str;
        view_stack.visible_child_name = "error";
    }

    private void maybe_toast_scan_errors () {
        if (scan_error_count > 0) {
            toast_overlay.add_toast (new Adw.Toast (
                "%u folders couldn't be scanned".printf (scan_error_count)
            ));
        }
    }

    private void show_all_clean_page (string title, string description) {
        skip_button.visible = false;
        all_clean_page.title = title;
        all_clean_page.description = description;
        view_stack.visible_child_name = "all-clean";
    }

    private void show_results_page () {
        skip_button.visible = true;
        view_stack.visible_child_name = "results";
    }

    // Deliberately a real `async` method using `yield` throughout, rather
    // than `.begin(...)` + a nested callback: capturing an array *parameter*
    // (`files`) in a closure that reads it later from a non-yield async
    // callback silently corrupts it - confirmed via two separate crashes
    // this session, the second one a regression reintroduced by an earlier
    // version of this exact method. Using `yield` keeps `files` a plain
    // parameter of one coroutine instead of something captured across a
    // callback boundary.
    private async void confirm_and_trash (
        File[] files,
        string heading,
        string body,
        string noun_plural,
        owned TrashCompletionHandler on_done
    ) {
        if (files.length == 0) {
            return;
        }

        var dialog = new Adw.AlertDialog (heading, body);
        dialog.add_response ("cancel", "Cancel");
        dialog.add_response ("trash", "Move to Trash");
        dialog.set_response_appearance ("trash", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.default_response = "cancel";
        dialog.close_response = "cancel";

        var response = yield dialog.choose (this, null);
        if (response != "trash") {
            return;
        }

        trash_button.sensitive = false;
        var op = new TrashOperation ();
        var result = yield op.run (files, new Cancellable ());
        show_trash_result_toast (result, noun_plural);
        on_done (result);
    }

    private void show_trash_result_toast (TrashResult result, string noun_plural) {
        if (result.failed_files.length > 0) {
            toast_overlay.add_toast (new Adw.Toast (
                "Moved %u %s to Trash, %u failed".printf (result.succeeded_files.length, noun_plural, result.failed_files.length)
            ));
        } else {
            toast_overlay.add_toast (new Adw.Toast (
                "Moved %u %s to Trash".printf (result.succeeded_files.length, noun_plural)
            ));
        }
    }

    //
    // Step: duplicate files
    //

    private void start_duplicate_scan (File folder) {
        current_step = CleanupStep.DUPLICATE_FILES;
        reset_scan_errors ();

        scanner = new DuplicateScanner ();
        scan_cancellable = new Cancellable ();

        scanner.progress.connect (on_duplicate_scan_progress);
        scanner.error_occurred.connect (on_scan_error);
        scanner.completed.connect (on_duplicate_scan_completed);
        scanner.cancelled.connect (() => finish_duplicate_step ());

        groups_list.bind_model (scanner.groups, create_group_row_widget);

        skip_button.visible = false;
        trash_button.sensitive = false;
        scanning_page.title = "Scanning…";
        progress_bar.fraction = 0;
        view_stack.visible_child_name = "scanning";

        scanner.run.begin (folder, scan_cancellable);
    }

    private void on_duplicate_scan_progress (ScanPhase scan_phase, uint64 current, uint64 total) {
        if (scan_phase == ScanPhase.WALKING) {
            progress_bar.pulse ();
        } else {
            progress_bar.fraction = total == 0 ? 1.0 : (double) current / (double) total;
        }
    }

    private void on_duplicate_scan_completed () {
        if (scanner.groups.get_n_items () == 0) {
            if (scan_error_count > 0) {
                show_scan_error_page ();
            } else {
                finish_duplicate_step ();
            }
            return;
        }

        update_duplicate_summary_label ();
        show_results_page ();
        maybe_toast_scan_errors ();
    }

    private void update_duplicate_summary_label () {
        var group_count = scanner.groups.get_n_items ();
        uint64 total_wasted = 0;
        for (uint i = 0; i < group_count; i++) {
            var group = (DuplicateGroup) scanner.groups.get_item (i);
            total_wasted += (uint64) group.wasted_bytes;
        }
        summary_label.label = "%u duplicate groups found — %s wasted".printf (
            group_count,
            GLib.format_size ((int64) total_wasted)
        );
    }

    private Gtk.Widget create_group_row_widget (Object item) {
        var group = (DuplicateGroup) item;
        group.auto_select_duplicates ();

        var row = new DuplicateGroupRow (group, current_scan_root);
        row.selection_toggled.connect (update_duplicate_trash_button);
        update_duplicate_trash_button ();
        return row;
    }

    private void update_duplicate_trash_button () {
        trash_button.sensitive = SelectionSummary.compute (scanner.groups).count > 0;
    }

    private void on_trash_duplicate_clicked () {
        var summary = SelectionSummary.compute (scanner.groups);
        var files = TrashOperation.selected_files (scanner.groups);

        confirm_and_trash.begin (
            files,
            "Move %u Files to Trash?".printf (summary.count),
            "These files (%s) will be moved to the Trash. You can restore them from there if needed.".printf (
                GLib.format_size (summary.bytes)
            ),
            "files",
            (result) => apply_duplicate_trash_result (result)
        );
    }

    private void apply_duplicate_trash_result (TrashResult result) {
        foreach (var file in result.succeeded_files) {
            remove_candidate_by_file (file);
        }
        // Whether or not every selected duplicate succeeded, a Clean action
        // on files always moves on to the next step.
        finish_duplicate_step ();
    }

    private void remove_candidate_by_file (File file) {
        for (uint i = 0; i < scanner.groups.get_n_items (); i++) {
            var group = (DuplicateGroup) scanner.groups.get_item (i);
            for (uint j = 0; j < group.files.get_n_items (); j++) {
                var candidate = (CandidateFile) group.files.get_item (j);
                if (candidate.file.equal (file)) {
                    group.files.remove (j);
                    if (group.files.get_n_items () < 2) {
                        scanner.groups.remove (i);
                    }
                    return;
                }
            }
        }
    }

    private void finish_duplicate_step () {
        start_empty_folder_scan ();
    }

    //
    // Step: empty folders (currently the last step in the chain)
    //

    private void start_empty_folder_scan () {
        current_step = CleanupStep.EMPTY_FOLDERS;
        reset_scan_errors ();

        empty_folder_scanner = new EmptyFolderScanner ();
        scan_cancellable = new Cancellable ();

        empty_folder_scanner.error_occurred.connect (on_scan_error);
        empty_folder_scanner.completed.connect (on_empty_folder_scan_completed);
        empty_folder_scanner.cancelled.connect (() => finish_empty_folder_step ());

        skip_button.visible = false;
        trash_button.sensitive = false;
        scanning_page.title = "Scanning for Empty Folders…";
        progress_bar.pulse ();
        view_stack.visible_child_name = "scanning";

        empty_folder_scanner.run.begin (current_scan_root, scan_cancellable);
    }

    private void on_empty_folder_scan_completed () {
        if (empty_folder_scanner.folders.get_n_items () == 0) {
            if (scan_error_count > 0) {
                show_scan_error_page ();
            } else {
                finish_empty_folder_step ();
            }
            return;
        }

        empty_folder_scanner.select_all ();
        groups_list.bind_model (empty_folder_scanner.folders, create_empty_folder_row_widget);
        update_empty_folder_summary_label ();
        update_empty_folder_trash_button ();
        show_results_page ();
        maybe_toast_scan_errors ();
    }

    private void update_empty_folder_summary_label () {
        summary_label.label = "%u empty folders found".printf (empty_folder_scanner.folders.get_n_items ());
    }

    private Gtk.Widget create_empty_folder_row_widget (Object item) {
        var folder = (EmptyFolder) item;
        var row = new EmptyFolderRow (folder, current_scan_root);
        row.selection_toggled.connect (update_empty_folder_trash_button);
        return row;
    }

    private void update_empty_folder_trash_button () {
        trash_button.sensitive = count_selected_folders () > 0;
    }

    private uint count_selected_folders () {
        uint count = 0;
        for (uint i = 0; i < empty_folder_scanner.folders.get_n_items (); i++) {
            if (((EmptyFolder) empty_folder_scanner.folders.get_item (i)).selected) {
                count++;
            }
        }
        return count;
    }

    private void on_trash_empty_folder_clicked () {
        var files = TrashOperation.selected_folders (empty_folder_scanner.folders);

        confirm_and_trash.begin (
            files,
            "Move %u Empty Folders to Trash?".printf (files.length),
            "These folders will be moved to the Trash. You can restore them from there if needed.",
            "folders",
            (result) => apply_empty_folder_trash_result (result)
        );
    }

    private void apply_empty_folder_trash_result (TrashResult result) {
        foreach (var file in result.succeeded_files) {
            remove_empty_folder_by_file (file);
        }

        if (empty_folder_scanner.folders.get_n_items () == 0) {
            finish_empty_folder_step ();
            return;
        }

        update_empty_folder_summary_label ();
        update_empty_folder_trash_button ();
    }

    private void remove_empty_folder_by_file (File file) {
        for (uint i = 0; i < empty_folder_scanner.folders.get_n_items (); i++) {
            var folder = (EmptyFolder) empty_folder_scanner.folders.get_item (i);
            if (folder.file.equal (file)) {
                empty_folder_scanner.folders.remove (i);
                return;
            }
        }
    }

    private void finish_empty_folder_step () {
        show_all_clean_page ("All Clean", "No empty folders left to remove.");
    }
}
