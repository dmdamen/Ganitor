public enum Ganitor.ScanPhase {
    WALKING,
    HASHING
}

public class Ganitor.DuplicateScanner : GLib.Object {
    private const int CHUNK_SIZE = 262144; // 256 KiB

    public ListStore groups { get; private set; }

    public signal void progress (ScanPhase phase, uint64 current, uint64 total);
    public signal void error_occurred (File location, Error error);
    public signal void completed ();
    public signal void cancelled ();

    private uint64 files_seen;
    private uint64 bytes_hashed;
    private uint64 total_bytes_to_hash;

    construct {
        groups = new ListStore (typeof (DuplicateGroup));
    }

    public async void run (File root, Cancellable cancellable) {
        var size_buckets = new HashTable<int64?, GenericArray<CandidateFile>> (int64_hash, int64_equal);
        files_seen = 0;

        try {
            yield walk (root, size_buckets, cancellable);
        } catch (IOError.CANCELLED e) {
            cancelled ();
            return;
        } catch (Error e) {
            error_occurred (root, e);
        }

        var candidate_buckets = new GenericArray<GenericArray<CandidateFile>> ();
        size_buckets.foreach ((size, bucket) => {
            if (bucket.length >= 2) {
                candidate_buckets.add (bucket);
            }
        });

        total_bytes_to_hash = 0;
        foreach (var bucket in candidate_buckets) {
            total_bytes_to_hash += (uint64) bucket[0].size * (uint64) bucket.length;
        }
        bytes_hashed = 0;
        progress (ScanPhase.HASHING, 0, total_bytes_to_hash);

        foreach (var bucket in candidate_buckets) {
            var checksum_groups = new HashTable<string, DuplicateGroup> (str_hash, str_equal);

            foreach (var candidate in bucket) {
                string? checksum = null;
                try {
                    checksum = yield compute_checksum (candidate.file, cancellable);
                } catch (IOError.CANCELLED e) {
                    cancelled ();
                    return;
                } catch (Error e) {
                    error_occurred (candidate.file, e);
                    continue;
                }

                candidate.checksum = checksum;

                var group = checksum_groups.lookup (checksum);
                if (group == null) {
                    group = new DuplicateGroup (checksum, candidate.size);
                    checksum_groups.insert (checksum, group);
                }
                group.add_file (candidate);
            }

            checksum_groups.foreach ((checksum, group) => {
                if (group.files.get_n_items () >= 2) {
                    groups.append (group);
                }
            });
        }

        completed ();
    }

    private async void walk (File dir, HashTable<int64?, GenericArray<CandidateFile>> buckets, Cancellable cancellable) throws IOError {
        FileEnumerator enumerator;
        try {
            enumerator = yield dir.enumerate_children_async (
                "standard::name,standard::type,standard::size,time::modified",
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                Priority.DEFAULT,
                cancellable
            );
        } catch (IOError.CANCELLED e) {
            throw e;
        } catch (Error e) {
            error_occurred (dir, e);
            return;
        }

        while (true) {
            List<FileInfo> infos;
            try {
                infos = yield enumerator.next_files_async (32, Priority.DEFAULT, cancellable);
            } catch (IOError.CANCELLED e) {
                throw e;
            } catch (Error e) {
                error_occurred (dir, e);
                break;
            }

            if (infos.length () == 0) {
                break;
            }

            foreach (var info in infos) {
                if (info.get_file_type () == FileType.SYMBOLIC_LINK) {
                    continue;
                }

                var child = dir.get_child (info.get_name ());

                if (info.get_file_type () == FileType.DIRECTORY) {
                    yield walk (child, buckets, cancellable);
                } else if (info.get_file_type () == FileType.REGULAR) {
                    var size = info.get_size ();
                    if (size <= 0) {
                        continue;
                    }

                    files_seen++;
                    progress (ScanPhase.WALKING, files_seen, 0);

                    var candidate = new CandidateFile (child, info);
                    var bucket = buckets.lookup (size);
                    if (bucket == null) {
                        bucket = new GenericArray<CandidateFile> ();
                        buckets.insert (size, bucket);
                    }
                    bucket.add (candidate);
                }
            }
        }
    }

    private async string compute_checksum (File file, Cancellable cancellable) throws Error {
        var stream = yield file.read_async (Priority.DEFAULT, cancellable);
        var checksum = new Checksum (ChecksumType.SHA256);
        var buffer = new uint8[CHUNK_SIZE];

        while (true) {
            var bytes_read = yield stream.read_async (buffer, Priority.DEFAULT, cancellable);
            if (bytes_read <= 0) {
                break;
            }

            checksum.update (buffer, bytes_read);
            bytes_hashed += bytes_read;
            progress (ScanPhase.HASHING, bytes_hashed, total_bytes_to_hash);
        }

        yield stream.close_async (Priority.DEFAULT, cancellable);
        return checksum.get_string ().dup ();
    }
}
