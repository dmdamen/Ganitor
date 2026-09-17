namespace Ganitor.Format {
    public string button_label (Summary summary) {
        if (summary.count == 0) {
            return "Clean";
        }

        var size = GLib.format_size (summary.bytes);
        if (summary.count == 1) {
            return "Move 1 File to Trash (%s)".printf (size);
        }

        return "Move %u Files to Trash (%s)".printf (summary.count, size);
    }
}
