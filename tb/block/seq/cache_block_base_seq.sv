// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Stimulus vocabulary for the block environment. Each helper issues one
// operation and states what its result must be.
class cache_block_base_seq extends uvm_sequence #(cache_block_txn);

    `uvm_object_utils(cache_block_base_seq)

    function new(string name = "cache_block_base_seq");
        super.new(name);
    endfunction

    // ---- L1 line memory --------------------------------------------------

    virtual task l1_write(bit [BLK_INDEX_WIDTH-1:0] addr,
                          bit [BLK_LINE_WIDTH-1:0] data,
                          bit [(BLK_LINE_WIDTH/8)-1:0] be,
                          string label);
        cache_block_txn t = cache_block_txn::type_id::create("t");
        start_item(t);
        t.op          = BLK_L1_ARRAY_WRITE;
        t.addr        = addr;
        t.line_data   = data;
        t.byte_enable = be;
        t.label       = label;
        finish_item(t);
    endtask

    virtual task l1_read_expect(bit [BLK_INDEX_WIDTH-1:0] addr,
                                bit [BLK_LINE_WIDTH-1:0] expected,
                                string label);
        cache_block_txn t = cache_block_txn::type_id::create("t");
        start_item(t);
        t.op         = BLK_L1_ARRAY_READ;
        t.addr       = addr;
        t.check_line = 1'b1;
        t.exp_line   = expected;
        t.label      = label;
        finish_item(t);
    endtask

    // ---- L1 tag/valid array ----------------------------------------------

    virtual task tag_write(bit [BLK_INDEX_WIDTH-1:0] addr,
                           bit [BLK_TAG_WIDTH:0] data,
                           string label);
        cache_block_txn t = cache_block_txn::type_id::create("t");
        start_item(t);
        t.op       = BLK_TAG_WRITE;
        t.addr     = addr;
        t.tag_data = data;
        t.label    = label;
        finish_item(t);
    endtask

    virtual task tag_read_expect(bit [BLK_INDEX_WIDTH-1:0] addr,
                                 bit [BLK_TAG_WIDTH:0] expected,
                                 string label);
        cache_block_txn t = cache_block_txn::type_id::create("t");
        start_item(t);
        t.op        = BLK_TAG_READ;
        t.addr      = addr;
        t.check_tag = 1'b1;
        t.exp_tag   = expected;
        t.label     = label;
        finish_item(t);
    endtask

    virtual task tag_invalidate(bit [BLK_INDEX_WIDTH-1:0] addr,
                                bit [BLK_TAG_WIDTH-1:0] tag,
                                string label);
        cache_block_txn t = cache_block_txn::type_id::create("t");
        start_item(t);
        t.op             = BLK_TAG_INVALIDATE;
        t.addr           = addr;
        t.invalidate_tag = tag;
        t.label          = label;
        finish_item(t);
    endtask

    // ---- L2 dual-port line memory ----------------------------------------

    virtual task l2_write(bit [BLK_INDEX_WIDTH-1:0] addr_p1,
                          bit [BLK_INDEX_WIDTH-1:0] addr_p2,
                          bit [BLK_LINE_WIDTH-1:0] data_p1,
                          bit [BLK_LINE_WIDTH-1:0] data_p2,
                          bit [(BLK_LINE_WIDTH/8)-1:0] be_p1,
                          bit [(BLK_LINE_WIDTH/8)-1:0] be_p2,
                          string label);
        cache_block_txn t = cache_block_txn::type_id::create("t");
        start_item(t);
        t.op             = BLK_L2_WRITE;
        t.addr           = addr_p1;
        t.addr_p2        = addr_p2;
        t.line_data      = data_p1;
        t.line_data_p2   = data_p2;
        t.byte_enable    = be_p1;
        t.byte_enable_p2 = be_p2;
        t.label          = label;
        finish_item(t);
    endtask

    virtual task l2_read_expect(bit [BLK_INDEX_WIDTH-1:0] addr_p1,
                                bit [BLK_INDEX_WIDTH-1:0] addr_p2,
                                bit [BLK_LINE_WIDTH-1:0] exp_p1,
                                bit [BLK_LINE_WIDTH-1:0] exp_p2,
                                string label);
        cache_block_txn t = cache_block_txn::type_id::create("t");
        start_item(t);
        t.op            = BLK_L2_READ;
        t.addr          = addr_p1;
        t.addr_p2       = addr_p2;
        t.check_line    = 1'b1;
        t.exp_line      = exp_p1;
        t.check_line_p2 = 1'b1;
        t.exp_line_p2   = exp_p2;
        t.label         = label;
        finish_item(t);
    endtask

    // ---- load/store helpers ----------------------------------------------

    virtual task load_expect(bit [BLK_LINE_WIDTH-1:0] block,
                             bit [1:0] word, bit [1:0] offset,
                             bit [BLK_DATA_WIDTH-1:0] expected,
                             string label);
        cache_block_txn t = cache_block_txn::type_id::create("t");
        start_item(t);
        t.op         = BLK_LOAD;
        t.line_data  = block;
        t.word       = word;
        t.offset     = offset;
        t.check_word = 1'b1;
        t.exp_word   = expected;
        t.label      = label;
        finish_item(t);
    endtask

    virtual task store_expect(bit write_l2,
                              bit [BLK_LINE_WIDTH-1:0] data_l2,
                              bit [BLK_DATA_WIDTH-1:0] wdata,
                              bit [(BLK_DATA_WIDTH/8)-1:0] wstrb,
                              bit [1:0] word, bit [1:0] offset,
                              bit check_be, bit [(BLK_LINE_WIDTH/8)-1:0] exp_be,
                              bit check_line, bit [BLK_LINE_WIDTH-1:0] exp_line,
                              string label);
        cache_block_txn t = cache_block_txn::type_id::create("t");
        start_item(t);
        t.op                = BLK_STORE;
        t.write_l2          = write_l2;
        t.line_data         = data_l2;
        t.word_data         = wdata;
        t.word_strobe       = wstrb;
        t.word              = word;
        t.offset            = offset;
        t.check_byte_enable = check_be;
        t.exp_byte_enable   = exp_be;
        t.check_line        = check_line;
        t.exp_line          = exp_line;
        t.label             = label;
        finish_item(t);
    endtask

endclass
