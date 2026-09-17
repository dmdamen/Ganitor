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
    private unowned Gtk.ProgressBar progress_bar;
    [GtkChild]
    private unowned Gtk.Button cancel_scan_button;
    [GtkChild]
    private unowned Gtk.Label summary_label;
    [GtkChild]
    private unowned Gtk.ListBox groups_list;
    [GtkChild]
    private unowned Adw.StatusPage error_page;

    private Settings settings;
    private DuplicateScanner? scanner;
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
        scan_error_count = 0;
        scan_error_text = new StringBuilder ();

        scanner = new DuplicateScanner ();
        current_scan_root = folder;
        scan_cancellable = new Cancellable ();

        scanner.progress.connect (on_scan_progress);
        scanner.error_occurred.connect (on_scan_error);
        scanner.completed.connect (on_scan_completed);
        scanner.cancelled.connect (on_scan_cancelled);

        groups_list.bind_model (scanner.groups, create_group_row_widget);

        trash_button.sensitive = false;

        progress_bar.fraction = 0;
        view_stack.visible_child_name = "scanning";

        scanner.run.begin (folder, scan_cancellable);
    }

    private void on_scan_progress (ScanPhase phase, uint64 current, uint64 total) {
        if (phase == ScanPhase.WALKING) {
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
        view_stack.visible_child_name = "empty";
    }

    private void on_scan_completed () {
        if (scanner.groups.get_n_items () == 0) {
            if (scan_error_count > 0) {
                error_page.description = scan_error_text.str;
                view_stack.visible_child_name = "error";
            } else {
                view_stack.visible_child_name = "no-duplicates";
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

    private void update_summary_label () {
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
        row.selection_toggled.connect (update_trash_button);
        update_trash_button ();
        return row;
    }

    private void update_trash_button () {
        trash_button.sensitive = SelectionSummary.compute (scanner.groups).count > 0;
    }

    private void on_trash_clicked () {
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
            var response = dialog.choose.end (res);
            if (response == "trash") {
                perform_trash (files);
            }
        });
    }

    private void perform_trash (File[] files) {
        var op = new TrashOperation ();
        op.run.begin (files, new Cancellable (), (obj, res) => {
            var result = op.run.end (res);
            apply_trash_result (files, result);
        });
    }

    private void apply_trash_result (File[] attempted_files, TrashResult result) {
        var failed = new HashTable<File, bool> ((f) => f.hash (), (a, b) => a.equal (b));
        foreach (var file in result.failed_files) {
            failed.insert (file, true);
        }

        foreach (var file in attempted_files) {
            if (!failed.contains (file)) {
                remove_candidate_by_file (file);
            }
        }

        update_summary_label ();
        update_trash_button ();

        if (scanner.groups.get_n_items () == 0) {
            view_stack.visible_child_name = "no-duplicates";
        }

        if (result.failed_files.length > 0) {
            toast_overlay.add_toast (new Adw.Toast (
                "Moved %u files to Trash, %u failed".printf (result.succeeded, result.failed_files.length)
            ));
        } else {
            toast_overlay.add_toast (new Adw.Toast (
                "Moved %u files to Trash".printf (result.succeeded)
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
}
