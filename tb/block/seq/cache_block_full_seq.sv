// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// The full block-level suite, one section per leaf module.
//
// Ported from the directed block testbench this replaces, check for check. The
// literal expectations are kept verbatim: they encode byte-lane placement and
// replacement-policy decisions that are the whole point of these tests, and
// recomputing them from a model here would just restate the RTL.
class cache_block_full_seq extends cache_block_base_seq;

    `uvm_object_utils(cache_block_full_seq)

    function new(string name = "cache_block_full_seq");
        super.new(name);
    endfunction

    task body();
        test_l1_array();
        test_l1_tag_valid_array();
        test_l2_array();
        test_load_store_helpers();
        test_replacement_helpers();
        test_controller_line_fill();
    endtask

    // A byte-enabled write must modify only the enabled lanes and leave the
    // rest of the previously-zeroed line alone.
    protected task test_l1_array();
        l1_write(2'd1, '0, 16'hffff, "l1 array clear");
        l1_write(2'd1, 128'hffff_eeee_dddd_cccc_bbbb_aaaa_9999_8888, 16'h000f,
                 "l1 byte-enabled write");
        l1_read_expect(2'd1, 128'h0000_0000_0000_0000_0000_0000_9999_8888,
                       "l1 byte-enabled write");
    endtask

    // Address-selective invalidate must clear the valid bit for a matching tag.
    protected task test_l1_tag_valid_array();
        tag_write(2'd2, {1'b1, 5'h15}, "tag write");
        tag_read_expect(2'd2, {1'b1, 5'h15}, "tag write reads back valid");
        tag_invalidate(2'd2, 5'h15, "tag invalidate");
        tag_read_expect(2'd2, {1'b0, 5'h15}, "tag invalidate clears valid");
    endtask

    // Both ports write independently, and port 2's byte enables must confine
    // its write to the enabled lanes.
    protected task test_l2_array();
        l2_write(2'd0, 2'd3, '0, '0, 16'hffff, 16'hffff, "l2 clear both ports");
        l2_write(2'd0, 2'd3,
                 128'h1111_2222_3333_4444_5555_6666_7777_8888,
                 128'haaaa_bbbb_cccc_dddd_eeee_ffff_0000_1234,
                 16'hffff, 16'h00ff, "l2 dual-port write");
        l2_read_expect(2'd0, 2'd3,
                       128'h1111_2222_3333_4444_5555_6666_7777_8888,
                       128'h0000_0000_0000_0000_eeee_ffff_0000_1234,
                       "l2 port write/read");
    endtask

    protected task test_load_store_helpers();
        // Load extracts the correct 64 bits for a given word/offset.
        load_expect(128'h00112233445566778899aabbccddeeff, 2'd1, 2'd2,
                    64'h2233445566778899, "l1 load byte placement");

        // Store maps a strobed 64-bit write onto line byte enables.
        store_expect(.write_l2(1'b0), .data_l2('0),
                     .wdata(64'h0102_0304_0506_0708), .wstrb(8'h3c),
                     .word(2'd1), .offset(2'd1),
                     .check_be(1'b1), .exp_be(16'h0780),
                     .check_line(1'b0), .exp_line('0),
                     .label("l1 store byte enable placement"));

        // In L2-fill mode the whole line is written through unchanged.
        store_expect(.write_l2(1'b1),
                     .data_l2(128'h1234_5678_90ab_cdef_fedc_ba09_8765_4321),
                     .wdata(64'h0102_0304_0506_0708), .wstrb(8'h3c),
                     .word(2'd1), .offset(2'd1),
                     .check_be(1'b1), .exp_be(16'hffff),
                     .check_line(1'b1),
                     .exp_line(128'h1234_5678_90ab_cdef_fedc_ba09_8765_4321),
                     .label("l1 store fill block"));

        // Leave the helper out of fill mode for later operations.
        store_expect(.write_l2(1'b0), .data_l2('0), .wdata('0), .wstrb('0),
                     .word(2'd0), .offset(2'd0),
                     .check_be(1'b0), .exp_be('0),
                     .check_line(1'b0), .exp_line('0),
                     .label("l1 store idle"));
    endtask

    protected task test_replacement_helpers();
        cache_block_txn t;

        // An empty set fills way 0 first.
        t = cache_block_txn::type_id::create("t");
        start_item(t);
        t.op = BLK_L1_REPL; t.rep_write = 1'b1;
        t.rep_valid_s1 = 1'b0; t.rep_valid_s2 = 1'b0;
        t.check_we = 1'b1; t.exp_we_s1 = 1'b1; t.exp_we_s2 = 1'b0;
        t.label = "l1 replacement empty writes way 0";
        finish_item(t);

        // With way 0 valid, the invalid way 1 is filled next.
        t = cache_block_txn::type_id::create("t");
        start_item(t);
        t.op = BLK_L1_REPL; t.rep_write = 1'b1;
        t.rep_valid_s1 = 1'b1; t.rep_valid_s2 = 1'b0;
        t.check_we = 1'b1; t.exp_we_s1 = 1'b0; t.exp_we_s2 = 1'b1;
        t.label = "l1 replacement fills invalid way 1";
        finish_item(t);

        // Read-hit way 0, which makes way 1 least recently used.
        t = cache_block_txn::type_id::create("t");
        start_item(t);
        t.op = BLK_L1_REPL; t.rep_read = 1'b1; t.rep_hit_s1 = 1'b1;
        t.rep_valid_s1 = 1'b1; t.rep_valid_s2 = 1'b1;
        t.advance_clock = 1'b1;
        t.label = "l1 replacement read hit way 0";
        finish_item(t);

        // Both ways valid, so the write must evict the least recently used one.
        t = cache_block_txn::type_id::create("t");
        start_item(t);
        t.op = BLK_L1_REPL; t.rep_write = 1'b1;
        t.rep_valid_s1 = 1'b1; t.rep_valid_s2 = 1'b1;
        t.check_we = 1'b1; t.exp_we_s1 = 1'b0; t.exp_we_s2 = 1'b1;
        t.label = "l1 replacement evicts least recently used way 1";
        finish_item(t);

        // Two L2 ports writing the same index must be steered to different
        // ways, or they would collide on one line.
        t = cache_block_txn::type_id::create("t");
        start_item(t);
        t.op = BLK_L2_REPL;
        t.rep_write = 1'b1; t.rep_write_p2 = 1'b1;
        t.addr = 2'd1; t.addr_p2 = 2'd1;
        t.rep_ram_write_start = 1'b1;
        t.check_we    = 1'b1; t.exp_we_s1    = 1'b1; t.exp_we_s2    = 1'b0;
        t.check_we_p2 = 1'b1; t.exp_we_s1_p2 = 1'b0; t.exp_we_s2_p2 = 1'b1;
        t.label = "l2 same-index dual-port write selection";
        finish_item(t);

        // Release the L2 replacement inputs.
        t = cache_block_txn::type_id::create("t");
        start_item(t);
        t.op = BLK_L2_REPL; t.advance_clock = 1'b1;
        t.label = "l2 replacement idle";
        finish_item(t);
    endtask

    // A data-side line fill must issue exactly one memory read per beat, with
    // ascending beat indices.
    protected task test_controller_line_fill();
        cache_block_txn t = cache_block_txn::type_id::create("t");
        start_item(t);
        t.op          = BLK_CTRL_LINE_FILL;
        t.check_beats = 1'b1;
        t.exp_beats   = 4;
        t.label       = "controller data line fill";
        finish_item(t);
    endtask

endclass
