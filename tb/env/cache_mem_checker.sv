// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

`uvm_analysis_imp_decl(_beat)
`uvm_analysis_imp_decl(_cpu_write)

// Protocol checker for the native memory request channel.
//
// Burst metadata is redundant information — burst, burst_len, beat_index,
// burst_start and burst_last all describe the same transfer — so it is checked
// for self-consistency on every beat, and against an independently predicted
// length for line fills and write-throughs. A memory-side adaptor is entitled
// to trust these fields, which is exactly why they need checking here rather
// than being assumed correct because the data happened to arrive.
class cache_mem_checker extends uvm_component;

    uvm_analysis_imp_beat      #(cache_mem_obs_txn,  cache_mem_checker) beat_imp;
    uvm_analysis_imp_cpu_write #(cache_data_obs_txn, cache_mem_checker) cpu_write_imp;

    static const int       LINE_MEM_BEAT_COUNT = LINE_WIDTH_P / MEM_DATA_WIDTH_P;
    static const bit [7:0] LINE_MEM_LAST_BEAT  = 8'(LINE_MEM_BEAT_COUNT - 1);

    // Base of the cache's memory window, mirroring MEMORY_BASE_ADDR in
    // cache_controller. Beat addresses are checked against it, so a write that
    // lands on the right beat of the wrong line is caught.
    static const bit [31:0] MEMORY_BASE_ADDR = 32'h2000_0000;

    // Armed by an observed CPU store, disarmed once its burst completes.
    protected bit       write_check_active = 0;
    protected bit [7:0] expected_burst_len = 8'd1;
    protected bit [7:0] expected_beat      = 8'd0;
    protected string    write_label        = "";

    // The store being written through, kept so each beat's payload can be
    // predicted rather than only its shape.
    protected bit [ADDR_WIDTH_P-1:0]         write_addr  = '0;
    protected bit [DATA_WIDTH_P-1:0]         write_data  = '0;
    protected bit [(DATA_WIDTH_P/8)-1:0]     write_strb  = '0;

    int unsigned beats_checked = 0;

    `uvm_component_utils(cache_mem_checker)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        beat_imp      = new("beat_imp",      this);
        cpu_write_imp = new("cpu_write_imp", this);
    endfunction

    // How many memory beats a CPU store must occupy: the store's byte lanes are
    // placed at its offset within a memory word, and the burst has to reach the
    // highest beat any enabled lane lands in.
    static function bit [7:0] predict_write_burst_len(bit [ADDR_WIDTH_P-1:0] addr,
                                                      bit [(DATA_WIDTH_P/8)-1:0] wstrb);
        int unsigned mem_bytes = MEM_DATA_WIDTH_P / 8;
        bit [7:0]    last_beat = 8'd0;
        for (int lane = 0; lane < (DATA_WIDTH_P / 8); lane++) begin
            int unsigned byte_offset = lane + (32'(addr) % mem_bytes);
            int unsigned beat        = byte_offset / mem_bytes;
            if (wstrb[lane] && (beat > last_beat)) last_beat = beat[7:0];
        end
        return last_beat + 8'd1;
    endfunction

    // What one memory write beat must carry, derived from the CPU store by the
    // same byte-lane mapping that fixes the burst length: data byte `lane` of a
    // store at address A belongs at byte address A+lane, and therefore in beat
    // (A%mem_bytes + lane)/mem_bytes at slot (A%mem_bytes + lane)%mem_bytes.
    //
    // Checking this and not only the burst shape is what catches a write-through
    // that reaches memory with the right number of beats but the bytes in the
    // wrong places — which is invisible to a read-back that hits in L1, because
    // the L1 copy is written by a different path.
    protected function void predict_write_beat(
            input  bit [7:0]                       beat,
            output bit [(MEM_DATA_WIDTH_P/8)-1:0]  exp_strb,
            output bit [MEM_DATA_WIDTH_P-1:0]      exp_data);
        int unsigned mem_bytes = MEM_DATA_WIDTH_P / 8;
        exp_strb = '0;
        exp_data = '0;
        for (int lane = 0; lane < (DATA_WIDTH_P / 8); lane++) begin
            int unsigned byte_index = lane + (32'(write_addr) % mem_bytes);
            if (write_strb[lane] && ((byte_index / mem_bytes) == beat)) begin
                int unsigned slot = byte_index % mem_bytes;
                exp_strb[slot]          = 1'b1;
                exp_data[slot*8 +: 8]   = write_data[lane*8 +: 8];
            end
        end
    endfunction

    // Byte address of the first beat: the store's memory word, not the store's
    // own address, since a burst always opens on a word boundary.
    protected function bit [31:0] expected_beat_addr(bit [7:0] beat);
        int unsigned mem_bytes = MEM_DATA_WIDTH_P / 8;
        int unsigned base      = 32'(write_addr) - (32'(write_addr) % mem_bytes);
        return MEMORY_BASE_ADDR + 32'(base + (beat * mem_bytes));
    endfunction

    // Every CPU store must produce a complete write burst before the next one
    // arrives. Write-through is the only source of memory writes and the cache
    // handles one store at a time, so a store whose burst never started, or
    // stopped short, has silently failed to reach memory.
    //
    // Checking only the beats that *arrive* cannot see this: a store that emits
    // nothing at all leaves the checker armed and waiting, and the next store
    // just re-arms it. That blind spot hid a lost single-byte store through two
    // rounds of write-path fixes.
    protected function void check_previous_write_completed(string next_label);
        if (!write_check_active) return;

        if (expected_beat != expected_burst_len)
            `uvm_error("WRITE_INCOMPLETE",
                       $sformatf("%0s reached memory as %0d of %0d beat(s) before the next store (%0s); store 0x%0h at 0x%0h wstrb 0x%0h",
                                 write_label, expected_beat, expected_burst_len,
                                 next_label, write_data, write_addr, write_strb))
    endfunction

    function void write_cpu_write(cache_data_obs_txn t);
        check_previous_write_completed(t.label);
        write_check_active = 1'b1;
        expected_burst_len = predict_write_burst_len(t.addr, t.wstrb);
        expected_beat      = 8'd0;
        write_label        = t.label;
        write_addr         = t.addr;
        write_data         = t.wdata;
        write_strb         = t.wstrb;
        `uvm_info("MEM_CHECKER_TRACE",
                  $sformatf("ARM addr=0x%0h wstrb=0x%0h -> expect burst_len=%0d (%0s)",
                            t.addr, t.wstrb, expected_burst_len, t.label), UVM_HIGH)
    endfunction

    function void write_beat(cache_mem_obs_txn t);
        beats_checked++;
        `uvm_info("MEM_CHECKER_TRACE",
                  $sformatf("BEAT %0s addr=0x%0h len=%0d beat=%0d start=%0b last=%0b wstrb=0x%0h cpu_busy=%0b cpu_write=%0b",
                            t.write ? "WR" : "RD", t.addr, t.burst_len, t.beat_index,
                            t.burst_start, t.burst_last, t.wstrb,
                            t.cpu_busy, t.cpu_write), UVM_HIGH)
        if (t.write) check_write_beat(t);
        else         check_read_beat(t);
    endfunction

    // Address, byte enables and the enabled data bytes of one write beat.
    //
    // Only strobed lanes are compared: a masked byte is not required to carry
    // any particular value, and the memory must not use it either way.
    protected function void check_write_payload(cache_mem_obs_txn t);
        bit [(MEM_DATA_WIDTH_P/8)-1:0] exp_strb;
        bit [MEM_DATA_WIDTH_P-1:0]     exp_data;
        bit [31:0]                     exp_addr = expected_beat_addr(t.beat_index);

        predict_write_beat(t.beat_index, exp_strb, exp_data);

        if (t.addr !== exp_addr)
            `uvm_error("WRITE_ADDR_MISMATCH",
                       $sformatf("%0s beat %0d address expected=0x%0h actual=0x%0h",
                                 write_label, t.beat_index, exp_addr, t.addr))

        if (t.wstrb !== exp_strb)
            `uvm_error("WRITE_STRB_MISMATCH",
                       $sformatf("%0s beat %0d byte enables expected=0x%0h actual=0x%0h (store 0x%0h at 0x%0h wstrb 0x%0h)",
                                 write_label, t.beat_index, exp_strb, t.wstrb,
                                 write_data, write_addr, write_strb))

        for (int b = 0; b < (MEM_DATA_WIDTH_P / 8); b++) begin
            if (exp_strb[b] && t.wstrb[b] &&
                (t.wdata[b*8 +: 8] !== exp_data[b*8 +: 8]))
                `uvm_error("WRITE_DATA_MISMATCH",
                           $sformatf("%0s beat %0d byte %0d expected=0x%0h actual=0x%0h (store 0x%0h at 0x%0h wstrb 0x%0h)",
                                     write_label, t.beat_index, b,
                                     exp_data[b*8 +: 8], t.wdata[b*8 +: 8],
                                     write_data, write_addr, write_strb))
        end
    endfunction

    protected function void check_write_beat(cache_mem_obs_txn t);
        if (write_check_active) begin
            if (t.burst_len !== expected_burst_len)
                `uvm_error("BURST_MISMATCH",
                           $sformatf("%0s write burst_len expected=%0d actual=%0d",
                                     write_label, expected_burst_len, t.burst_len))
            if (t.beat_index !== expected_beat)
                `uvm_error("BURST_MISMATCH",
                           $sformatf("%0s write beat_index expected=%0d actual=%0d",
                                     write_label, expected_beat, t.beat_index))

            check_write_payload(t);
        end

        check_metadata_consistency(t, write_label);


        // Saturate rather than disarm. Every write beat this cache emits belongs
        // to the most recent CPU store — write-through is the only source of
        // memory writes — so staying armed until the next store means a burst
        // that runs long is caught by its beat index instead of slipping
        // through unchecked.
        if (write_check_active && (expected_beat != expected_burst_len))
            expected_beat++;
    endfunction

    // A line fill always transfers the whole line, so its shape is fixed by the
    // geometry and does not need arming by stimulus.
    protected function void check_read_beat(cache_mem_obs_txn t);
        if (LINE_MEM_BEAT_COUNT == 1) begin
            if (t.burst || (t.burst_len !== 8'd1) || (t.beat_index !== 8'd0) ||
                t.burst_start || t.burst_last)
                `uvm_error("BURST_MISMATCH",
                           $sformatf("single-beat read metadata burst=%0b len=%0d beat=%0d start=%0b last=%0b",
                                     t.burst, t.burst_len, t.beat_index,
                                     t.burst_start, t.burst_last))
        end else begin
            if (!t.burst || (t.burst_len !== 8'(LINE_MEM_BEAT_COUNT)) ||
                (t.beat_index > LINE_MEM_LAST_BEAT) ||
                (t.burst_start !== (t.beat_index == 8'd0)) ||
                (t.burst_last  !== (t.beat_index == LINE_MEM_LAST_BEAT)))
                `uvm_error("BURST_MISMATCH",
                           $sformatf("read metadata burst=%0b len=%0d beat=%0d start=%0b last=%0b",
                                     t.burst, t.burst_len, t.beat_index,
                                     t.burst_start, t.burst_last))
        end
    endfunction

    // burst/start/last must agree with burst_len and beat_index on every beat,
    // independent of what the transfer is for.
    protected function void check_metadata_consistency(cache_mem_obs_txn t, string label);
        bit exp_burst = (t.burst_len != 8'd1);
        bit exp_start = exp_burst && (t.beat_index == 8'd0);
        bit exp_last  = exp_burst && (t.beat_index == (t.burst_len - 8'd1));

        if ((t.burst !== exp_burst) || (t.burst_start !== exp_start) ||
            (t.burst_last !== exp_last))
            `uvm_error("BURST_MISMATCH",
                       $sformatf("%0s write metadata burst=%0b len=%0d beat=%0d start=%0b last=%0b",
                                 label, t.burst, t.burst_len, t.beat_index,
                                 t.burst_start, t.burst_last))
    endfunction

    function void report_phase(uvm_phase phase);
        // The last store of a run has no successor to trigger the completion
        // check, so it is checked here instead.
        check_previous_write_completed("end of test");

        `uvm_info("MEM_CHECKER",
                  $sformatf("checked %0d memory request beats", beats_checked), UVM_LOW)
    endfunction

endclass
