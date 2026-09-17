// The cleanup flow has two phases sharing the same header-bar "Clean"
// button, the same scanning/results pages, and the same trash mechanism:
// first duplicate files, then (once those are actually cleaned, not merely
// found) empty folders left behind. Which phase is active determines what
// on_trash_clicked/apply_trash_result/update_trash_button etc. operate on.
private enum Ganitor.CleanupPhase {
    DUPLICATES,
    EMPTY_FOLDERS
}

[GtkTemplate (ui = "/io/github/dmdamen/Ganitor/window.ui")]
public class Ganitor.Window : Adw.ApplicationWindow {
    [GtkChild]
    private unowned Gtk.Button select_folder_button;
    [GtkChild]
    private unowned Gtk.Button trash_button;
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

    private Settings settings;
    private CleanupPhase phase;
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
            start_scan (folder);
        });
    }

    private void start_scan (File folder) {
        phase = CleanupPhase.DUPLICATES;
        current_scan_root = folder;
        reset_scan_errors ();

        scanner = new DuplicateScanner ();
        scan_cancellable = new Cancellable ();

        scanner.progress.connect (on_scan_progress);
        scanner.error_occurred.connect (on_scan_error);
        scanner.completed.connect (on_duplicate_scan_completed);
        scanner.cancelled.connect (on_scan_cancelled);

        groups_list.bind_model (scanner.groups, create_group_row_widget);

        trash_button.sensitive = false;
        scanning_page.title = "Scanning…";
        progress_bar.fraction = 0;
        view_stack.visible_child_name = "scanning";

        scanner.run.begin (folder, scan_cancellable);
    }

    private void reset_scan_errors () {
        scan_error_count = 0;
        scan_error_text = new StringBuilder ();
    }

    private void on_scan_progress (ScanPhase scan_phase, uint64 current, uint64 total) {
        if (scan_phase == ScanPhase.WALKING) {
            progress_bar.pulse ();
        } else {
            progress_bar.fraction = total == 0 ? 1.0 : (double) current / (double) total;
        }
    }

    private void on_scan_error (File location, Error error) {
        scan_error_count++;
        scan_error_text.append_printf (
            "%s: %s\n",
            location.get_path () ?? location.get_uri (),
            error.message
        );
    }

    private void on_cancel_clicked () {
        if (scan_cancellable != null) {
            scan_cancellable.cancel ();
        }
    }

    private void on_scan_cancelled () {
        if (phase == CleanupPhase.DUPLICATES) {
            view_stack.visible_child_name = "empty";
        } else {
            show_all_clean_page ("All Clean", "Empty folder check skipped.");
        }
    }

    private void on_duplicate_scan_completed () {
        if (scanner.groups.get_n_items () == 0) {
            if (scan_error_count > 0) {
                error_page.description = scan_error_text.str;
                view_stack.visible_child_name = "error";
            } else {
                show_all_clean_page ("No Duplicates Found", "This folder doesn't contain any duplicate files");
            }
            return;
        }

        update_summary_label ();
        view_stack.visible_child_name = "results";

        if (scan_error_count > 0) {
            toast_overlay.add_toast (new Adw.Toast (
                "%u folders couldn't be scanned".printf (scan_error_count)
            ));
        }
    }

    private void show_all_clean_page (string title, string description) {
        all_clean_page.title = title;
        all_clean_page.description = description;
        view_stack.visible_child_name = "no-duplicates";
    }

    private void update_summary_label () {
        if (phase == CleanupPhase.DUPLICATES) {
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
        } else {
            summary_label.label = "%u empty folders found".printf (empty_folder_scanner.folders.get_n_items ());
        }
    }

    private Gtk.Widget create_group_row_widget (Object item) {
        var group = (DuplicateGroup) item;
        group.auto_select_duplicates ();

        var row = new DuplicateGroupRow (group, current_scan_root);
        row.selection_toggled.connect (update_trash_button);
        update_trash_button ();
        return row;
    }

    private void update_trash_button () {
        if (phase == CleanupPhase.DUPLICATES) {
            trash_button.sensitive = SelectionSummary.compute (scanner.groups).count > 0;
        } else {
            trash_button.sensitive = count_selected_folders () > 0;
        }
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

    private void on_trash_clicked () {
        if (phase == CleanupPhase.DUPLICATES) {
            on_trash_duplicates_clicked ();
        } else {
            on_trash_empty_folders_clicked ();
        }
    }

    private void on_trash_duplicates_clicked () {
        var summary = SelectionSummary.compute (scanner.groups);
        var files = TrashOperation.selected_files (scanner.groups);
        if (files.length == 0) {
            return;
        }

        var dialog = new Adw.AlertDialog (
            "Move %u Files to Trash?".printf (summary.count),
            "These files (%s) will be moved to the Trash. You can restore them from there if needed.".printf (
                GLib.format_size (summary.bytes)
            )
        );
        dialog.add_response ("cancel", "Cancel");
        dialog.add_response ("trash", "Move to Trash");
        dialog.set_response_appearance ("trash", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.default_response = "cancel";
        dialog.close_response = "cancel";

        dialog.choose.begin (this, null, (obj, res) => {
            if (dialog.choose.end (res) == "trash") {
                perform_trash (files, "files");
            }
        });
    }

    private void on_trash_empty_folders_clicked () {
        var files = TrashOperation.selected_folders (empty_folder_scanner.folders);
        if (files.length == 0) {
            return;
        }

        var dialog = new Adw.AlertDialog (
            "Move %u Empty Folders to Trash?".printf (files.length),
            "These folders will be moved to the Trash. You can restore them from there if needed."
        );
        dialog.add_response ("cancel", "Cancel");
        dialog.add_response ("trash", "Move to Trash");
        dialog.set_response_appearance ("trash", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.default_response = "cancel";
        dialog.close_response = "cancel";

        dialog.choose.begin (this, null, (obj, res) => {
            if (dialog.choose.end (res) == "trash") {
                perform_trash (files, "folders");
            }
        });
    }

    private void perform_trash (File[] files, string noun_plural) {
        // Guard against a second trash operation overlapping this one (e.g.
        // a rapid double-click) — re-enabled once this one finishes.
        trash_button.sensitive = false;

        var op = new TrashOperation ();
        // apply_trash_result only needs the result, not the `files` this
        // callback closes over: capturing an array *parameter* and then
        // reading its contents from within a run.begin(...) callback
        // (rather than via `yield` inside an actual async method) turned
        // out to silently corrupt it - confirmed via a coredump showing the
        // captured array's length reading back as 0 here, causing a crash.
        // TrashOperation.run() now reports succeeded/failed files directly
        // in TrashResult instead, sidestepping that pattern entirely.
        op.run.begin (files, new Cancellable (), (obj, res) => {
            apply_trash_result (op.run.end (res), noun_plural);
        });
    }

    private void apply_trash_result (TrashResult result, string noun_plural) {
        show_trash_result_toast (result, noun_plural);

        if (phase == CleanupPhase.DUPLICATES) {
            foreach (var file in result.succeeded_files) {
                remove_candidate_by_file (file);
            }
            // Whether or not every selected duplicate was removed, a Clean
            // action on files always moves on to checking for empty
            // folders next - this only runs after an actual cleanup
            // action, not merely after a scan that happened to find some.
            start_empty_folder_scan ();
        } else {
            foreach (var file in result.succeeded_files) {
                remove_folder_by_file (file);
            }
            update_summary_label ();
            update_trash_button ();
            if (empty_folder_scanner.folders.get_n_items () == 0) {
                show_all_clean_page ("All Clean", "No empty folders left to remove.");
            }
        }
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

    private void remove_folder_by_file (File file) {
        for (uint i = 0; i < empty_folder_scanner.folders.get_n_items (); i++) {
            var folder = (EmptyFolder) empty_folder_scanner.folders.get_item (i);
            if (folder.file.equal (file)) {
                empty_folder_scanner.folders.remove (i);
                return;
            }
        }
    }

    private void start_empty_folder_scan () {
        phase = CleanupPhase.EMPTY_FOLDERS;
        reset_scan_errors ();

        empty_folder_scanner = new EmptyFolderScanner ();
        scan_cancellable = new Cancellable ();

        empty_folder_scanner.error_occurred.connect (on_scan_error);
        empty_folder_scanner.completed.connect (on_empty_folder_scan_completed);
        empty_folder_scanner.cancelled.connect (on_scan_cancelled);

        trash_button.sensitive = false;
        scanning_page.title = "Scanning for Empty Folders…";
        progress_bar.pulse ();
        view_stack.visible_child_name = "scanning";

        empty_folder_scanner.run.begin (current_scan_root, scan_cancellable);
    }

    private void on_empty_folder_scan_completed () {
        if (empty_folder_scanner.folders.get_n_items () == 0) {
            show_all_clean_page ("All Clean", "No empty folders left to remove.");
            return;
        }

        empty_folder_scanner.select_all ();
        groups_list.bind_model (empty_folder_scanner.folders, create_empty_folder_row_widget);
        update_summary_label ();
        update_trash_button ();
        view_stack.visible_child_name = "results";

        if (scan_error_count > 0) {
            toast_overlay.add_toast (new Adw.Toast (
                "%u folders couldn't be scanned".printf (scan_error_count)
            ));
        }
    }

    private Gtk.Widget create_empty_folder_row_widget (Object item) {
        var folder = (EmptyFolder) item;
        var row = new EmptyFolderRow (folder, current_scan_root);
        row.selection_toggled.connect (update_trash_button);
        return row;
    }
}
