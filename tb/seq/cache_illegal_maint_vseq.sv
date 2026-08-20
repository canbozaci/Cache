// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Negative maintenance testing: every illegal request combination must retire
// with maint_error rather than silently doing something.
//
// This matters more than it looks. A cache that quietly picks one of two
// conflicting maintenance requests will pass every positive test and then
// corrupt an integrator's coherency assumptions in the field, so the contract
// is that ambiguity is rejected, not resolved.
class cache_illegal_maint_vseq extends cache_base_vseq;

    `uvm_object_utils(cache_illegal_maint_vseq)

    function new(string name = "cache_illegal_maint_vseq");
        super.new(name);
    endfunction

    task body();
        wait_idle("illegal maintenance idle entry");

        // flush and invalidate asserted together
        maint_cmd(1, 1, 0, 0, 0, '0, 1, "global flush plus invalidate");

        // line flush and line invalidate asserted together
        maint_cmd(0, 0, 1, 1, 1, '0, 1, "line flush plus invalidate");

        // global and line maintenance asserted together
        maint_cmd(1, 0, 1, 0, 1, '0, 1, "global plus line maintenance");

        // line maintenance with no address supplied
        maint_cmd(0, 0, 0, 1, 0, '0, 1, "line maintenance without address");

        wait_idle("illegal maintenance idle exit");
    endtask

endclass
