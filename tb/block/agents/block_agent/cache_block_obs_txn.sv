// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// What the block DUT actually produced, paired with what was required.
class cache_block_obs_txn extends uvm_sequence_item;

    cache_block_op_e op;
    string           label = "";

    bit [BLK_LINE_WIDTH-1:0]     line;
    bit [BLK_LINE_WIDTH-1:0]     line_p2;
    bit [BLK_TAG_WIDTH:0]        tag;
    bit [BLK_DATA_WIDTH-1:0]     word_out;
    bit [(BLK_LINE_WIDTH/8)-1:0] byte_enable_out;
    bit                          we_s1;
    bit                          we_s2;
    bit                          we_s1_p2;
    bit                          we_s2_p2;
    int unsigned                 beats;

    // Carried straight through from the stimulus item so the scoreboard has
    // both sides of the comparison in one place.
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

    `uvm_object_utils(cache_block_obs_txn)

    function new(string name = "cache_block_obs_txn");
        super.new(name);
    endfunction

    // Copy the expectation across, so the driver does not have to enumerate
    // every field at each publish site.
    function void take_expectation(cache_block_txn t);
        op                = t.op;
        label             = t.label;
        check_line        = t.check_line;        exp_line        = t.exp_line;
        check_line_p2     = t.check_line_p2;     exp_line_p2     = t.exp_line_p2;
        check_tag         = t.check_tag;         exp_tag         = t.exp_tag;
        check_word        = t.check_word;        exp_word        = t.exp_word;
        check_byte_enable = t.check_byte_enable; exp_byte_enable = t.exp_byte_enable;
        check_we          = t.check_we;          exp_we_s1       = t.exp_we_s1;
                                                 exp_we_s2       = t.exp_we_s2;
        check_we_p2       = t.check_we_p2;       exp_we_s1_p2    = t.exp_we_s1_p2;
                                                 exp_we_s2_p2    = t.exp_we_s2_p2;
        check_beats       = t.check_beats;       exp_beats       = t.exp_beats;
    endfunction

endclass
