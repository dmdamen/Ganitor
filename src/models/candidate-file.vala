public class Ganitor.CandidateFile : GLib.Object {
    public File file { get; construct; }
    public int64 size { get; construct; }
    public DateTime modified_time { get; construct; }
    public string? checksum { get; set; default = null; }
    public bool selected { get; set; default = false; }

    // Gio.File.get_path() returns null for some backends (confirmed for at
    // least one Flatpak document-portal case). get_parse_name() always
    // returns a usable display string regardless of backend, so it's the
    // fallback rather than letting null reach display code.
    public string path {
        owned get { return file.get_path () ?? file.get_parse_name (); }
    }

    public CandidateFile (File file, FileInfo info) {
        Object (
            file: file,
            size: info.get_size (),
            modified_time: info.get_modification_date_time ()
        );
    }
}
