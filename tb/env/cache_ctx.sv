// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Shared test context: the small amount of state that sequences, monitors and
// the scoreboard all have to agree on.
//
// `mem_read_count` exists because several of this IP's contracts are stated in
// terms of memory traffic rather than data values. "This read must hit" and
// "this line must refill after invalidate" are only checkable by counting
// memory read handshakes across a stimulus step, so sequences snapshot the
// counter, drive, and compare. Keeping it here rather than inside the
// scoreboard lets a sequence assert on it without reaching into a checker.
class cache_ctx extends uvm_object;

    // Incremented by the memory monitor on every read request handshake.
    int unsigned mem_read_count = 0;

    // Human-readable tag for the stimulus currently in flight. Monitors attach
    // it to observations so a scoreboard mismatch names the step that caused
    // it, the way the legacy testbench's labels did.
    string label = "";

    // Override for the next instruction fetch: check against `instr_expected`
    // rather than the reference model. Needed for the documented I/D
    // incoherency contract, where a stale hit is the *correct* result and the
    // reference model has already moved on.
    bit        instr_use_expected = 0;
    bit [31:0] instr_expected     = '0;

    // Expected outcome of the maintenance command currently in flight. The
    // monitor cannot infer this from the bus — whether a request combination is
    // legal is a property of the contract, not of the waveform — so the
    // sequence declares it here.
    bit        maint_expect_error = 0;

    `uvm_object_utils(cache_ctx)

    function new(string name = "cache_ctx");
        super.new(name);
    endfunction

endclass
