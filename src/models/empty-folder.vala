public class Ganitor.EmptyFolder : GLib.Object {
    public File file { get; construct; }
    public bool selected { get; set; default = false; }

    public EmptyFolder (File file) {
        Object (file: file);
    }
}
