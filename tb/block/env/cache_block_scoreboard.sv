// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Compares each block operation's observed result against its stated
// requirement, and owns all pass/fail reporting for the block environment.
class cache_block_scoreboard extends uvm_scoreboard;

    uvm_analysis_imp #(cache_block_obs_txn, cache_block_scoreboard) imp;

    int unsigned checks = 0;

    `uvm_component_utils(cache_block_scoreboard)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        imp = new("imp", this);
    endfunction

    function void write(cache_block_obs_txn t);
        if (t.check_line) begin
            checks++;
            if (t.line !== t.exp_line)
                `uvm_error("BLOCK_LINE_MISMATCH",
                           $sformatf("%0s expected=%032h actual=%032h",
                                     t.label, t.exp_line, t.line))
        end

        if (t.check_line_p2) begin
            checks++;
            if (t.line_p2 !== t.exp_line_p2)
                `uvm_error("BLOCK_LINE_MISMATCH",
                           $sformatf("%0s (port 2) expected=%032h actual=%032h",
                                     t.label, t.exp_line_p2, t.line_p2))
        end

        if (t.check_tag) begin
            checks++;
            if (t.tag !== t.exp_tag)
                `uvm_error("BLOCK_TAG_MISMATCH",
                           $sformatf("%0s expected=%0h actual=%0h",
                                     t.label, t.exp_tag, t.tag))
        end

        if (t.check_word) begin
            checks++;
            if (t.word_out !== t.exp_word)
                `uvm_error("BLOCK_WORD_MISMATCH",
                           $sformatf("%0s expected=%016h actual=%016h",
                                     t.label, t.exp_word, t.word_out))
        end

        if (t.check_byte_enable) begin
            checks++;
            if (t.byte_enable_out !== t.exp_byte_enable)
                `uvm_error("BLOCK_BE_MISMATCH",
                           $sformatf("%0s expected=%04h actual=%04h",
                                     t.label, t.exp_byte_enable, t.byte_enable_out))
        end

        if (t.check_we) begin
            checks++;
            if ((t.we_s1 !== t.exp_we_s1) || (t.we_s2 !== t.exp_we_s2))
                `uvm_error("BLOCK_WE_MISMATCH",
                           $sformatf("%0s expected we_s1=%0b we_s2=%0b actual we_s1=%0b we_s2=%0b",
                                     t.label, t.exp_we_s1, t.exp_we_s2, t.we_s1, t.we_s2))
        end

        if (t.check_we_p2) begin
            checks++;
            if ((t.we_s1_p2 !== t.exp_we_s1_p2) || (t.we_s2_p2 !== t.exp_we_s2_p2))
                `uvm_error("BLOCK_WE_MISMATCH",
                           $sformatf("%0s (port 2) expected we_s1=%0b we_s2=%0b actual we_s1=%0b we_s2=%0b",
                                     t.label, t.exp_we_s1_p2, t.exp_we_s2_p2,
                                     t.we_s1_p2, t.we_s2_p2))
        end

        if (t.check_beats) begin
            checks++;
            if (t.beats != t.exp_beats)
                `uvm_error("BLOCK_CTRL_MISMATCH",
                           $sformatf("%0s expected %0d line-fill reads, saw %0d",
                                     t.label, t.exp_beats, t.beats))
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("BLOCK_SCOREBOARD",
                  $sformatf("checked %0d block expectations", checks), UVM_LOW)

        // A run that checked nothing must not look like a passing run.
        if (checks == 0)
            `uvm_error("NO_CHECKS", "block scoreboard evaluated no expectations")
    endfunction

endclass
