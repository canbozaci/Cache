`timescale 1ns / 1ps

module cache_scoreboard_tb #(
    parameter ADDR_WIDTH = 19,
    parameter DATA_WIDTH = 64,
    parameter MEM_DATA_WIDTH = 32,
    parameter LINE_WIDTH = 128,
    parameter RAM_ADDR_WIDTH = 17,
    parameter REF_BYTES = 4096,
    parameter MEM_READY_STALLS = 0
) ();
    localparam REF_WORDS = REF_BYTES / 4;
    localparam MEM_ADDR_LSB = (MEM_DATA_WIDTH == 64) ? 3 : 2;

    reg clk;
    reg rst;
    reg maint_flush_req;
    reg maint_invalidate_req;
    reg [1:0] mem_ready_counter;

    reg instr_req_valid;
    reg data_req_read;
    reg data_req_write;
    reg [ADDR_WIDTH-1:0] instr_req_addr;
    reg [ADDR_WIDTH-1:0] data_req_addr;
    reg [DATA_WIDTH-1:0] data_req_wdata;
    reg [(DATA_WIDTH/8)-1:0] data_req_wstrb;

    wire [31:0] instr_resp_data;
    wire [DATA_WIDTH-1:0] data_resp_rdata;
    wire [MEM_DATA_WIDTH-1:0] mem_rsp_rdata;
    wire [MEM_DATA_WIDTH-1:0] mem_req_wdata;
    wire [31:0] mem_req_addr;
    wire mem_req_valid;
    wire mem_req_ready;
    wire mem_req_write;
    wire [(MEM_DATA_WIDTH/8)-1:0] mem_req_wstrb;
    wire mem_rsp_ready;
    reg mem_rsp_valid;
    wire maint_ready;
    wire maint_done;
    wire maint_error;
    wire busy;

    reg [7:0] reference_memory [0:REF_BYTES-1];
    integer error_count;
    integer reference_word_index;
    integer reference_byte_index;
    reg [31:0] reference_word_value;

    assign mem_req_ready = (MEM_READY_STALLS == 0) ? 1'b1 : (mem_ready_counter != 2'd1);

    cache_memory_model #(
        .ADDR_WIDTH(RAM_ADDR_WIDTH),
        .DATA_WIDTH(MEM_DATA_WIDTH)
    ) main_memory (
        .clk(clk),
        .rst_ni(~rst),
        .write_addr(mem_req_addr[RAM_ADDR_WIDTH+MEM_ADDR_LSB-1:MEM_ADDR_LSB]),
        .read_addr(mem_req_addr[RAM_ADDR_WIDTH+MEM_ADDR_LSB-1:MEM_ADDR_LSB]),
        .write_data(mem_req_wdata),
        .write_strobe(mem_req_write ? mem_req_wstrb : {(MEM_DATA_WIDTH/8){1'b0}}),
        .read_enable(mem_req_valid && mem_req_ready && !mem_req_write),
        .ready(1'b1),
        .read_data(mem_rsp_rdata)
    );

    cache #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .MEM_DATA_WIDTH(MEM_DATA_WIDTH),
        .LINE_WIDTH(LINE_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .instr_req_valid(instr_req_valid),
        .instr_req_addr(instr_req_addr),
        .instr_resp_data(instr_resp_data),
        .data_req_read(data_req_read),
        .data_req_write(data_req_write),
        .data_req_addr(data_req_addr),
        .data_req_wdata(data_req_wdata),
        .data_req_wstrb(data_req_wstrb),
        .data_resp_rdata(data_resp_rdata),
        .mem_req_valid(mem_req_valid),
        .mem_req_ready(mem_req_ready),
        .mem_req_write(mem_req_write),
        .mem_req_addr(mem_req_addr),
        .mem_req_wdata(mem_req_wdata),
        .mem_req_wstrb(mem_req_wstrb),
        .mem_rsp_valid(mem_rsp_valid),
        .mem_rsp_ready(mem_rsp_ready),
        .mem_rsp_rdata(mem_rsp_rdata),
        .maint_flush_req(maint_flush_req),
        .maint_invalidate_req(maint_invalidate_req),
        .maint_ready(maint_ready),
        .maint_done(maint_done),
        .maint_error(maint_error),
        .busy(busy)
    );

    always #6.25 clk = ~clk;

    always @(posedge clk) begin
        if (rst) begin
            mem_ready_counter <= 2'b0;
            mem_rsp_valid <= 1'b0;
        end else begin
            mem_ready_counter <= mem_ready_counter + 2'd1;
            if (mem_rsp_ready) begin
                mem_rsp_valid <= mem_req_valid && mem_req_ready && !mem_req_write;
            end
        end
    end

    initial begin
        initialize_reference_memory();
        initialize_signals();
        reset_dut();

        check_maintenance_contract();

        expect_data_read(19'h00000, "data cold line 0 word 0");
        expect_data_read(19'h00004, "data hit line 0 word 1");
        expect_data_read(19'h00008, "data hit line 0 word 2");
        expect_data_read(19'h00020, "data cold line 2 word 0");

        expect_instr_read(19'h00000, "instruction cold line 0 word 0");
        expect_instr_read(19'h00004, "instruction hit line 0 word 1");

        apply_data_write(19'h00000, 64'h0000_0000_0000_00a5, 8'h01, "single byte write at line base");
        expect_data_read(19'h00000, "read after single byte write");

        apply_data_write(19'h00004, 64'h1122_3344_5566_7788, 8'hff, "aligned 64-bit write at word 1");
        expect_data_read(19'h00004, "read after aligned 64-bit write");

        apply_data_write(19'h00002, 64'haabb_ccdd_eeff_1234, 8'hff, "unaligned 64-bit write crossing three memory beats");
        expect_data_read(19'h00000, "read lower bytes after three-beat write");
        expect_data_read(19'h00008, "read upper bytes after three-beat write");

        apply_data_write(19'h00005, 64'h0000_0000_0000_00cc, 8'h01, "unaligned single byte write");
        expect_data_read(19'h00004, "read after unaligned single byte write");

        apply_data_write(19'h00010, 64'h0000_0000_dead_beef, 8'h0f, "aligned low-word partial write");
        expect_data_read(19'h00010, "read after low-word partial write");

        expect_data_read(19'h00004, "repeat hit after writes");
        expect_data_read(19'h00004, "second repeat hit after writes");
        expect_data_and_instr_read(19'h00020, 19'h00030, "simultaneous data and instruction reads");

        if (error_count == 0) begin
            $display("CACHE SCOREBOARD PASS");
            $finish;
        end else begin
            $display("CACHE SCOREBOARD FAIL: %0d mismatches", error_count);
            $fatal(1);
        end
    end

    task initialize_signals;
    begin
        clk = 1'b1;
        rst = 1'b1;
        maint_flush_req = 1'b0;
        maint_invalidate_req = 1'b0;
        mem_ready_counter = 2'b0;
        mem_rsp_valid = 1'b0;
        instr_req_valid = 1'b0;
        data_req_read = 1'b0;
        data_req_write = 1'b0;
        instr_req_addr = {ADDR_WIDTH{1'b0}};
        data_req_addr = {ADDR_WIDTH{1'b0}};
        data_req_wdata = {DATA_WIDTH{1'b0}};
        data_req_wstrb = {(DATA_WIDTH/8){1'b0}};
        error_count = 0;
    end
    endtask

    task check_maintenance_contract;
    begin
        wait_for_idle("maintenance idle entry");

        @(negedge clk);
        maint_flush_req = 1'b1;
        @(posedge clk);
        @(posedge clk);
        if (!maint_ready || !maint_done || maint_error) begin
            $display("MAINT MISMATCH: flush ready=%0b done=%0b error=%0b",
                     maint_ready, maint_done, maint_error);
            error_count = error_count + 1;
        end
        @(negedge clk);
        maint_flush_req = 1'b0;

        @(negedge clk);
        maint_invalidate_req = 1'b1;
        @(posedge clk);
        @(posedge clk);
        if (!maint_ready || !maint_done || maint_error) begin
            $display("MAINT MISMATCH: invalidate ready=%0b done=%0b error=%0b",
                     maint_ready, maint_done, maint_error);
            error_count = error_count + 1;
        end
        @(negedge clk);
        maint_invalidate_req = 1'b0;
        wait_for_idle("maintenance idle exit");
    end
    endtask

    task initialize_reference_memory;
    begin
        for (reference_word_index = 0; reference_word_index < REF_WORDS; reference_word_index = reference_word_index + 1) begin
            reference_word_value = 32'h1000_0000 ^ reference_word_index;
            for (reference_byte_index = 0; reference_byte_index < 4; reference_byte_index = reference_byte_index + 1) begin
                reference_memory[(reference_word_index * 4) + reference_byte_index] =
                    reference_word_value[reference_byte_index*8 +: 8];
            end
        end
    end
    endtask

    task reset_dut;
    begin
        repeat (8) @(posedge clk);
        rst = 1'b0;
        repeat (8) @(posedge clk);
    end
    endtask

    task wait_for_idle;
        input [1023:0] label;
        integer timeout_count;
    begin
        timeout_count = 0;
        repeat (2) @(posedge clk);
        while (busy || mem_req_valid || mem_rsp_valid) begin
            @(posedge clk);
            timeout_count = timeout_count + 1;
            if (timeout_count > 1000) begin
                $display("TIMEOUT: %0s did not become idle", label);
                error_count = error_count + 1;
                disable wait_for_idle;
            end
        end
        repeat (2) @(posedge clk);
    end
    endtask

    task wait_for_read_response;
        input [1023:0] label;
        integer timeout_count;
    begin
        timeout_count = 0;
        repeat (2) @(posedge clk);
        while (busy) begin
            @(posedge clk);
            timeout_count = timeout_count + 1;
            if (timeout_count > 1000) begin
                $display("TIMEOUT: %0s read response did not complete", label);
                error_count = error_count + 1;
                disable wait_for_read_response;
            end
        end
        @(posedge clk);
    end
    endtask

    task expect_data_read;
        input [ADDR_WIDTH-1:0] addr;
        input [1023:0] label;
        reg [DATA_WIDTH-1:0] expected_data;
    begin
        expected_data = read_reference64(addr);

        @(negedge clk);
        data_req_addr = addr;
        data_req_read = 1'b1;
        data_req_write = 1'b0;
        wait_for_read_response(label);
        compare_data(label, addr, expected_data, data_resp_rdata);
        @(negedge clk);
        data_req_read = 1'b0;
        wait_for_idle(label);
    end
    endtask

    task expect_instr_read;
        input [ADDR_WIDTH-1:0] addr;
        input [1023:0] label;
        reg [31:0] expected_instr;
    begin
        expected_instr = read_reference32(addr);

        @(negedge clk);
        instr_req_addr = addr;
        instr_req_valid = 1'b1;
        wait_for_read_response(label);
        compare_instr(label, addr, expected_instr, instr_resp_data);
        @(negedge clk);
        instr_req_valid = 1'b0;
        wait_for_idle(label);
    end
    endtask

    task expect_data_and_instr_read;
        input [ADDR_WIDTH-1:0] data_addr;
        input [ADDR_WIDTH-1:0] instr_addr;
        input [1023:0] label;
        reg [DATA_WIDTH-1:0] expected_data;
        reg [31:0] expected_instr;
    begin
        expected_data = read_reference64(data_addr);
        expected_instr = read_reference32(instr_addr);

        @(negedge clk);
        data_req_addr = data_addr;
        instr_req_addr = instr_addr;
        data_req_read = 1'b1;
        instr_req_valid = 1'b1;
        wait_for_read_response(label);
        compare_data(label, data_addr, expected_data, data_resp_rdata);
        compare_instr(label, instr_addr, expected_instr, instr_resp_data);
        @(negedge clk);
        data_req_read = 1'b0;
        instr_req_valid = 1'b0;
        wait_for_idle(label);
    end
    endtask

    task apply_data_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] write_data;
        input [(DATA_WIDTH/8)-1:0] write_strobe;
        input [1023:0] label;
    begin
        @(negedge clk);
        data_req_addr = addr;
        data_req_wdata = write_data;
        data_req_wstrb = write_strobe;
        data_req_write = 1'b1;
        data_req_read = 1'b0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        data_req_write = 1'b0;

        wait_for_idle(label);
        update_reference_write(addr, write_data, write_strobe);
        data_req_wstrb = {(DATA_WIDTH/8){1'b0}};
        data_req_wdata = {DATA_WIDTH{1'b0}};
    end
    endtask

    task compare_data;
        input [1023:0] label;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] expected_data;
        input [DATA_WIDTH-1:0] actual_data;
    begin
        if ((^actual_data) === 1'bx) begin
            $display("DATA X: %0s addr=0x%05h actual=%016h", label, addr, actual_data);
            error_count = error_count + 1;
        end else if (actual_data !== expected_data) begin
            $display("DATA MISMATCH: %0s addr=0x%05h expected=%016h actual=%016h",
                     label, addr, expected_data, actual_data);
            error_count = error_count + 1;
        end
    end
    endtask

    task compare_instr;
        input [1023:0] label;
        input [ADDR_WIDTH-1:0] addr;
        input [31:0] expected_instr;
        input [31:0] actual_instr;
    begin
        if ((^actual_instr) === 1'bx) begin
            $display("INSTR X: %0s addr=0x%05h actual=%08h", label, addr, actual_instr);
            error_count = error_count + 1;
        end else if (actual_instr !== expected_instr) begin
            $display("INSTR MISMATCH: %0s addr=0x%05h expected=%08h actual=%08h",
                     label, addr, expected_instr, actual_instr);
            error_count = error_count + 1;
        end
    end
    endtask

    task update_reference_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] write_data;
        input [(DATA_WIDTH/8)-1:0] write_strobe;
        integer byte_lane;
        integer byte_addr;
    begin
        for (byte_lane = 0; byte_lane < (DATA_WIDTH / 8); byte_lane = byte_lane + 1) begin
            byte_addr = addr + byte_lane;
            if (write_strobe[byte_lane] && (byte_addr < REF_BYTES)) begin
                reference_memory[byte_addr] = write_data[byte_lane*8 +: 8];
            end
        end
    end
    endtask

    function [DATA_WIDTH-1:0] read_reference64;
        input [ADDR_WIDTH-1:0] addr;
        integer byte_lane;
        integer byte_addr;
    begin
        read_reference64 = {DATA_WIDTH{1'b0}};
        for (byte_lane = 0; byte_lane < (DATA_WIDTH / 8); byte_lane = byte_lane + 1) begin
            byte_addr = addr + byte_lane;
            if (byte_addr < REF_BYTES) begin
                read_reference64[byte_lane*8 +: 8] = reference_memory[byte_addr];
            end
        end
    end
    endfunction

    function [31:0] read_reference32;
        input [ADDR_WIDTH-1:0] addr;
        integer byte_lane;
        integer byte_addr;
    begin
        read_reference32 = 32'b0;
        for (byte_lane = 0; byte_lane < 4; byte_lane = byte_lane + 1) begin
            byte_addr = addr + byte_lane;
            if (byte_addr < REF_BYTES) begin
                read_reference32[byte_lane*8 +: 8] = reference_memory[byte_addr];
            end
        end
    end
    endfunction

endmodule
