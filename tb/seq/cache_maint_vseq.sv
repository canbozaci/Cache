// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Global maintenance: flush then invalidate, both from an idle cache. Both must
// retire with done set and error clear.
class cache_maint_vseq extends cache_base_vseq;

    `uvm_object_utils(cache_maint_vseq)

    function new(string name = "cache_maint_vseq");
        super.new(name);
    endfunction

    task body();
        wait_idle("maintenance idle entry");
        global_flush("global flush");
        global_invalidate("global invalidate");
        wait_idle("maintenance idle exit");
    endtask

endclass
