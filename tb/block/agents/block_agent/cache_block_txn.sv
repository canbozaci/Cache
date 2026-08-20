// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Which leaf module a transaction targets, and what it does to it.
typedef enum {
    BLK_L1_ARRAY_WRITE,
    BLK_L1_ARRAY_READ,
    BLK_TAG_WRITE,
    BLK_TAG_READ,
    BLK_TAG_INVALIDATE,
    BLK_L2_WRITE,
    BLK_L2_READ,
    BLK_LOAD,
    BLK_STORE,
    BLK_L1_REPL,
    BLK_L2_REPL,
    BLK_CTRL_LINE_FILL
} cache_block_op_e;

// One block-level operation, carrying both the stimulus and what the result is
// required to be.
//
// The expectation travels with the item rather than living in the scoreboard.
// For leaf modules there is no protocol state to model — the correct answer for
// a given set of inputs is a property of that one operation, so the sequence
// that chose the inputs is the honest place to state it. The scoreboard still
// owns the comparison and the error reporting.
class cache_block_txn extends uvm_sequence_item;

    rand cache_block_op_e op;

    // --- stimulus, by operation -------------------------------------------
    rand bit [BLK_INDEX_WIDTH-1:0]      addr;
    rand bit [BLK_INDEX_WIDTH-1:0]      addr_p2;
    rand bit [BLK_LINE_WIDTH-1:0]       line_data;
    rand bit [BLK_LINE_WIDTH-1:0]       line_data_p2;
    rand bit [(BLK_LINE_WIDTH/8)-1:0]   byte_enable;
    rand bit [(BLK_LINE_WIDTH/8)-1:0]   byte_enable_p2;
    rand bit [BLK_TAG_WIDTH:0]          tag_data;
    rand bit [BLK_TAG_WIDTH-1:0]        invalidate_tag;

    rand bit [BLK_DATA_WIDTH-1:0]       word_data;
    rand bit [(BLK_DATA_WIDTH/8)-1:0]   word_strobe;
    rand bit [1:0]                      offset;
    rand bit [1:0]                      word;
    rand bit                            write_l2;

    // Replacement inputs. Named generically so one item covers both the L1 and
    // L2 replacement DUTs, which differ only in port count.
    rand bit                            rep_read;
    rand bit                            rep_write;
    rand bit                            rep_read_p2;
    rand bit                            rep_write_p2;
    rand bit                            rep_hit_s1;
    rand bit                            rep_hit_s2;
    rand bit                            rep_hit_s1_p2;
    rand bit                            rep_hit_s2_p2;
    rand bit                            rep_valid_s1;
    rand bit                            rep_valid_s2;
    rand bit                            rep_valid_s1_p2;
    rand bit                            rep_valid_s2_p2;
    rand bit                            rep_ram_write_start;
    rand bit                            rep_write_through;
    rand bit                            rep_write_l2;

    // When set, the operation advances a clock edge before sampling. Sequential
    // DUTs need it; combinational helpers must not have it.
    rand bit                            advance_clock;

    // --- expectation -------------------------------------------------------
    // Only the fields named by `check_*` are compared.
    bit                             check_line;
    bit [BLK_LINE_WIDTH-1:0]        exp_line;
    bit                             check_line_p2;
    bit [BLK_LINE_WIDTH-1:0]        exp_line_p2;
    bit                             check_tag;
    bit [BLK_TAG_WIDTH:0]           exp_tag;
    bit                             check_word;
    bit [BLK_DATA_WIDTH-1:0]        exp_word;
    bit                             check_byte_enable;
    bit [(BLK_LINE_WIDTH/8)-1:0]    exp_byte_enable;
    bit                             check_we;
    bit                             exp_we_s1;
    bit                             exp_we_s2;
    bit                             check_we_p2;
    bit                             exp_we_s1_p2;
    bit                             exp_we_s2_p2;
    bit                             check_beats;
    int unsigned                    exp_beats;

    string label = "";

    `uvm_object_utils_begin(cache_block_txn)
        `uvm_field_enum(cache_block_op_e, op, UVM_DEFAULT)
        `uvm_field_int(addr, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(line_data, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(byte_enable, UVM_DEFAULT | UVM_HEX)
        `uvm_field_string(label, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "cache_block_txn");
        super.new(name);
    endfunction

endclass
