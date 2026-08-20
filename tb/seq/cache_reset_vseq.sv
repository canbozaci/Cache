// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Reset recovery.
//
// Two distinct hazards: reset landing in the middle of an outstanding memory
// transaction (where the controller has state the memory side does not know
// about), and back-to-back short resets (where the second arrives before the
// first has finished draining). Both must leave the cache serving correct data,
// not merely responsive.
class cache_reset_vseq extends cache_base_vseq;

    `uvm_object_utils(cache_reset_vseq)

    function new(string name = "cache_reset_vseq");
        super.new(name);
    endfunction

    task body();
        bit [ADDR_WIDTH_P-1:0] addr_a = ADDR_WIDTH_P'(NEXT_LINE_ADDR * 2);
        bit [ADDR_WIDTH_P-1:0] addr_b = ADDR_WIDTH_P'(NEXT_LINE_ADDR * 3);

        wait_idle("reset contract idle entry");

        fork
            // This read is deliberately destroyed by the reset below; the
            // monitor discards it rather than checking a response that was
            // never produced.
            data_read(addr_a, "reset contract in-flight read");

            begin
                wait (vif.data_req_read);
                repeat (2) @(posedge vif.clk);
                if (!vif.busy && !vif.mem_req_valid)
                    `uvm_error("RESET_SETUP",
                               "expected an in-flight transaction before the reset pulse")
                reset_pulse(4);
            end
        join

        wait_idle("reset during transaction recovery");
        data_read(addr_a, "read after reset during transaction");

        // Short, repeated resets: the cache must tolerate a new reset arriving
        // before it has fully recovered from the previous one.
        reset_pulse(2);
        reset_pulse(3);
        reset_pulse(1);
        wait_idle("repeated reset recovery");

        instr_fetch(addr_b, "instruction read after repeated reset");
    endtask

endclass
