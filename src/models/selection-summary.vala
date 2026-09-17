public struct Ganitor.Summary {
    public uint count;
    public int64 bytes;
}

namespace Ganitor.SelectionSummary {
    public Summary compute (ListModel groups) {
        uint count = 0;
        int64 bytes = 0;

        for (uint i = 0; i < groups.get_n_items (); i++) {
            var group = (DuplicateGroup) groups.get_item (i);
            for (uint j = 0; j < group.files.get_n_items (); j++) {
                var candidate = (CandidateFile) group.files.get_item (j);
                if (candidate.selected) {
                    count++;
                    bytes += candidate.size;
                }
            }
        }

        return Summary () { count = count, bytes = bytes };
    }
}
