// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Virtual sequencer. The data and instruction ports share `busy`, so a test
// that exercises both at once has to coordinate them from one place rather than
// running two independent sequences that would each wait on the other's stalls.
class cache_vsqr extends uvm_sequencer;

    cache_data_sequencer  data_sqr;
    cache_instr_sequencer instr_sqr;
    cache_maint_sequencer maint_sqr;

    `uvm_component_utils(cache_vsqr)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass
