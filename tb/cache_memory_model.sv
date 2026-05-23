`timescale 1ns / 1ps

module cache_memory_model #(
    parameter ADDR_WIDTH = 17,
    parameter DATA_WIDTH = 32
) (
    input  clk,
    input  rst_ni,
    input  [ADDR_WIDTH-1:0]   write_addr,
    input  [ADDR_WIDTH-1:0]   read_addr,
    input  [DATA_WIDTH-1:0]   write_data,
    input  [(DATA_WIDTH/8)-1:0] write_strobe,
    input  read_enable,
    input  ready,
    output reg [DATA_WIDTH-1:0] read_data
);

    localparam BYTE_COUNT = DATA_WIDTH / 8;
    localparam MEM_DEPTH = 1 << ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] memory_q [0:MEM_DEPTH-1];

    integer init_index;
    integer byte_index;
    integer word_index;

    initial begin
        for (init_index = 0; init_index < MEM_DEPTH; init_index = init_index + 1) begin
            memory_q[init_index] = {DATA_WIDTH{1'b0}};
            for (word_index = 0; word_index < (DATA_WIDTH / 32); word_index = word_index + 1) begin
                memory_q[init_index][word_index*32 +: 32] =
                    32'h1000_0000 ^ ((init_index * (DATA_WIDTH / 32)) + word_index);
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_ni) begin
            read_data <= {DATA_WIDTH{1'b0}};
        end else begin
            if (read_enable && ready) begin
                read_data <= memory_q[read_addr];
            end

            for (byte_index = 0; byte_index < BYTE_COUNT; byte_index = byte_index + 1) begin
                if (ready && write_strobe[byte_index]) begin
                    memory_q[write_addr][byte_index*8 +: 8] <= write_data[byte_index*8 +: 8];
                end
            end
        end
    end

endmodule
