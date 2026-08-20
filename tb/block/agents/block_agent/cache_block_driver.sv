// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Drives the block-level DUTs and publishes what they produced.
//
// This driver samples and publishes its own results rather than relying on a
// separate monitor, and that is a deliberate departure from the cache-top
// environment. These DUTs are leaf modules: several are purely combinational,
// and none has a handshake. There is no protocol from which an independent
// observer could infer *when* a result is valid — the sampling instant is
// defined entirely by the stimulus. A monitor here could only duplicate the
// driver's timing, which would make it a copy rather than a check.
//
// The check itself still lives in the scoreboard, so the component that applies
// stimulus is not the component that decides pass or fail.
class cache_block_driver extends uvm_driver #(cache_block_txn);

    virtual cache_block_if vif;

    uvm_analysis_port #(cache_block_obs_txn) ap;

    `uvm_component_utils(cache_block_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cache_block_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for cache_block_driver")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            cache_block_obs_txn obs;
            seq_item_port.get_next_item(req);
            obs = cache_block_obs_txn::type_id::create("obs");
            obs.take_expectation(req);
            drive(req, obs);
            ap.write(obs);
            seq_item_port.item_done();
        end
    endtask

    protected task drive(cache_block_txn t, cache_block_obs_txn obs);
        case (t.op)
            BLK_L1_ARRAY_WRITE:  drive_l1_array_write(t);
            BLK_L1_ARRAY_READ:   drive_l1_array_read(t, obs);
            BLK_TAG_WRITE:       drive_tag_write(t);
            BLK_TAG_READ:        drive_tag_read(t, obs);
            BLK_TAG_INVALIDATE:  drive_tag_invalidate(t);
            BLK_L2_WRITE:        drive_l2_write(t);
            BLK_L2_READ:         drive_l2_read(t, obs);
            BLK_LOAD:            drive_load(t, obs);
            BLK_STORE:           drive_store(t, obs);
            BLK_L1_REPL:         drive_l1_repl(t, obs);
            BLK_L2_REPL:         drive_l2_repl(t, obs);
            BLK_CTRL_LINE_FILL:  drive_ctrl_line_fill(t, obs);
        endcase
    endtask

    // ---- L1 line memory --------------------------------------------------

    protected task drive_l1_array_write(cache_block_txn t);
        @(negedge vif.clk);
        vif.l1_array_addr        = t.addr;
        vif.l1_array_write_data  = t.line_data;
        vif.l1_array_byte_enable = t.byte_enable;
        vif.l1_array_we          = 1'b1;
    endtask

    protected task drive_l1_array_read(cache_block_txn t, cache_block_obs_txn obs);
        @(negedge vif.clk);
        vif.l1_array_we   = 1'b0;
        vif.l1_array_addr = t.addr;
        @(posedge vif.clk);
        @(negedge vif.clk);
        obs.line = vif.l1_array_read_data;
    endtask

    // ---- L1 tag/valid array ----------------------------------------------

    protected task drive_tag_write(cache_block_txn t);
        @(negedge vif.clk);
        vif.tag_addr       = t.addr;
        vif.tag_write_data = t.tag_data;
        vif.tag_we         = 1'b1;
    endtask

    protected task drive_tag_read(cache_block_txn t, cache_block_obs_txn obs);
        @(negedge vif.clk);
        vif.tag_we   = 1'b0;
        vif.tag_addr = t.addr;
        @(posedge vif.clk);
        @(negedge vif.clk);
        obs.tag = vif.tag_read_data;
    endtask

    protected task drive_tag_invalidate(cache_block_txn t);
        vif.tag_invalidate_addr = t.addr;
        vif.tag_invalidate_tag  = t.invalidate_tag;
        vif.tag_invalidate      = 1'b1;
        @(negedge vif.clk);
        vif.tag_invalidate      = 1'b0;
    endtask

    // ---- L2 dual-port line memory ----------------------------------------

    protected task drive_l2_write(cache_block_txn t);
        @(negedge vif.clk);
        vif.l2_addr_p1  = t.addr;
        vif.l2_addr_p2  = t.addr_p2;
        vif.l2_wdata_p1 = t.line_data;
        vif.l2_wdata_p2 = t.line_data_p2;
        vif.l2_be_p1    = t.byte_enable;
        vif.l2_be_p2    = t.byte_enable_p2;
        vif.l2_we_p1    = 1'b1;
        vif.l2_we_p2    = 1'b1;
    endtask

    protected task drive_l2_read(cache_block_txn t, cache_block_obs_txn obs);
        @(negedge vif.clk);
        vif.l2_we_p1   = 1'b0;
        vif.l2_we_p2   = 1'b0;
        vif.l2_addr_p1 = t.addr;
        vif.l2_addr_p2 = t.addr_p2;
        @(posedge vif.clk);
        @(negedge vif.clk);
        obs.line    = vif.l2_rdata_p1;
        obs.line_p2 = vif.l2_rdata_p2;
    endtask

    // ---- combinational load/store helpers --------------------------------
    //
    // No clock edge: these are pure functions of their inputs, so a settle
    // delta is all that is correct to wait for. Waiting for an edge would hide
    // a helper that only produced the right answer a cycle later.

    protected task drive_load(cache_block_txn t, cache_block_obs_txn obs);
        vif.load_block  = t.line_data;
        vif.load_word   = t.word;
        vif.load_offset = t.offset;
        #1;
        obs.word_out = vif.load_data;
    endtask

    protected task drive_store(cache_block_txn t, cache_block_obs_txn obs);
        vif.store_write_l2     = t.write_l2;
        vif.store_data_l2      = t.line_data;
        vif.store_write_data   = t.word_data;
        vif.store_write_strobe = t.word_strobe;
        vif.store_word         = t.word;
        vif.store_offset       = t.offset;
        #1;
        obs.byte_enable_out = vif.store_byte_enable;
        obs.line            = vif.store_data_in_write;
    endtask

    // ---- replacement policies --------------------------------------------

    protected task drive_l1_repl(cache_block_txn t, cache_block_obs_txn obs);
        vif.l1_rep_read          = t.rep_read;
        vif.l1_rep_write         = t.rep_write;
        vif.l1_rep_idx           = t.addr;
        vif.l1_rep_hit_s1        = t.rep_hit_s1;
        vif.l1_rep_hit_s2        = t.rep_hit_s2;
        vif.l1_rep_valid_s1      = t.rep_valid_s1;
        vif.l1_rep_valid_s2      = t.rep_valid_s2;
        vif.l1_rep_write_l2      = t.rep_write_l2;
        vif.l1_rep_write_through = t.rep_write_through;

        if (t.advance_clock) begin
            @(posedge vif.clk);
            @(negedge vif.clk);
        end else begin
            #1;
        end

        obs.we_s1 = vif.l1_rep_we_s1;
        obs.we_s2 = vif.l1_rep_we_s2;
    endtask

    protected task drive_l2_repl(cache_block_txn t, cache_block_obs_txn obs);
        vif.l2_rep_read_p1         = t.rep_read;
        vif.l2_rep_read_p2         = t.rep_read_p2;
        vif.l2_rep_write_p1        = t.rep_write;
        vif.l2_rep_write_p2        = t.rep_write_p2;
        vif.l2_rep_idx_p1          = t.addr;
        vif.l2_rep_idx_p2          = t.addr_p2;
        vif.l2_rep_hit_s1_p1       = t.rep_hit_s1;
        vif.l2_rep_hit_s2_p1       = t.rep_hit_s2;
        vif.l2_rep_hit_s1_p2       = t.rep_hit_s1_p2;
        vif.l2_rep_hit_s2_p2       = t.rep_hit_s2_p2;
        vif.l2_rep_valid_s1_p1     = t.rep_valid_s1;
        vif.l2_rep_valid_s2_p1     = t.rep_valid_s2;
        vif.l2_rep_valid_s1_p2     = t.rep_valid_s1_p2;
        vif.l2_rep_valid_s2_p2     = t.rep_valid_s2_p2;
        vif.l2_rep_ram_write_start = t.rep_ram_write_start;
        vif.l2_rep_write_through   = t.rep_write_through;

        if (t.advance_clock) begin
            @(posedge vif.clk);
            @(negedge vif.clk);
        end else begin
            #1;
        end

        obs.we_s1    = vif.l2_rep_we_s1_p1;
        obs.we_s2    = vif.l2_rep_we_s2_p1;
        obs.we_s1_p2 = vif.l2_rep_we_s1_p2;
        obs.we_s2_p2 = vif.l2_rep_we_s2_p2;
    endtask

    // ---- controller line-fill subflow ------------------------------------
    //
    // The only block operation with a real protocol: the controller issues one
    // memory read per beat and this acknowledges each. Beat indices are checked
    // here as they stream past, because they are only observable per beat; the
    // total is checked by the scoreboard.

    protected task drive_ctrl_line_fill(cache_block_txn t, cache_block_obs_txn obs);
        int unsigned beats   = 0;
        int unsigned timeout = 0;

        vif.ctrl_l1_data_addr      = 19'h00040;
        vif.ctrl_data_read_request = 1'b1;

        while ((beats < t.exp_beats) && (timeout < 200)) begin
            @(posedge vif.clk);
            vif.ctrl_ram_rsp_valid <= 1'b0;
            if (vif.ctrl_ram_read && vif.ctrl_ram_req_ready) begin
                if (vif.ctrl_ram_read_beat_index !== 8'(beats))
                    `uvm_error("BLOCK_CTRL",
                               $sformatf("%0s beat index expected=%0d actual=%0d",
                                         t.label, beats, vif.ctrl_ram_read_beat_index))
                beats++;
                vif.ctrl_ram_rsp_valid <= 1'b1;
            end
            timeout++;
        end

        vif.ctrl_data_read_request = 1'b0;
        vif.ctrl_ram_rsp_valid     = 1'b0;
        vif.ctrl_l1_data_hit       = 1'b1;
        repeat (8) @(posedge vif.clk);
        vif.ctrl_l1_data_hit       = 1'b0;

        obs.beats = beats;
    endtask

endclass
