public class Ganitor.CandidateFile : GLib.Object {
    public File file { get; construct; }
    public int64 size { get; construct; }
    public DateTime modified_time { get; construct; }
    public string? checksum { get; set; default = null; }
    public bool selected { get; set; default = false; }

    public string path {
        owned get { return file.get_path (); }
    }

    public CandidateFile (File file, FileInfo info) {
        Object (
            file: file,
            size: info.get_size (),
            modified_time: info.get_modification_date_time ()
        );
    }
}
