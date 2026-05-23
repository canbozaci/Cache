`timescale 1ns / 1ps

module Cache_MEM_L1_data#( // L1 data cache top module
    parameter block_size = 128,
    parameter tag_size = 9,
    parameter idx_size = 6,
    parameter block_no = 64,
    parameter word_size = 2,
    parameter offset_size = 2,
    parameter data_width = 64
    )
    ( 
    input clk,
    input rst,
    input read,  
    input write, 
    input write_L2, 
    input write_through,
    input [tag_size+idx_size+word_size+offset_size-1:0] addr, 
    input [data_width-1:0] write_data,
    input [(data_width/8)-1:0] write_strobe,
    input [block_size-1:0] data_L2,
    output [block_size-1:0]  data_block, 
    output [data_width-1:0] data,
    output hit 
    );
    // wires
    wire [block_size-1:0] data_in_write; 
    wire [7:0] byte_enable_l; 
    wire [7:0] byte_enable_h; 
    wire [tag_size -1:0] tag_input;
    wire [idx_size -1:0] idx_input;
    wire [word_size-1:0] word_input;
    wire [offset_size-1:0] offset_input;
    wire cache_set_output_select;
    wire [block_size -1:0] data_out_s1;
    wire [block_size -1:0] data_out_s2;
    wire [tag_size -1:0] tag_out_s1;
    wire [tag_size -1:0] tag_out_s2;
    wire valid_out_s1; // valid bits with addressing
    wire valid_out_s2; // valid bits with addressing
    wire we_s1;
    wire we_s2;
    wire hit_s1;
    wire hit_s2; 
    wire we_set1;
    wire we_set2;

    assign tag_input    = addr[tag_size + idx_size + word_size +  offset_size  - 1:idx_size + word_size + offset_size];
    assign idx_input    = addr[idx_size + word_size + offset_size - 1:word_size+offset_size];
    assign word_input   = addr[word_size+offset_size -1 :offset_size];
    assign offset_input = addr[offset_size-1:0];

    assign we_set2 = write & we_s2;
    assign we_set1 = write & we_s1;
    assign hit = ((read | write) & (hit_s1 | hit_s2)) & (~rst);
    assign cache_set_output_select = ((read | write) & (hit_s2 & (~hit_s1)));

    Cache_SET_L1_data#( // SET1
        .block_size(block_size),
        .tag_size(tag_size),
        .idx_size(idx_size)
        ) 
    cache_set_0(
        .clk(clk),
        .rst(rst),
        .block_write(data_in_write),
        .tag_and_idx({tag_input,idx_input}),
        .we(we_set1),
        .byte_enable({byte_enable_h,byte_enable_l}),
        .block_read(data_out_s1),
        .valid(valid_out_s1),
        .tag(tag_out_s1)
        );

    Cache_SET_L1_data#( // SET2
        .block_size(block_size),
        .tag_size(tag_size),
        .idx_size(idx_size)
        ) 
    cache_set_1(
        .clk(clk),
        .rst(rst),
        .block_write(data_in_write),
        .tag_and_idx({tag_input,idx_input}),
        .we(we_set2),
        .byte_enable({byte_enable_h,byte_enable_l}),
        .block_read(data_out_s2),
        .valid(valid_out_s2),
        .tag(tag_out_s2)
        );

    Cache_identification#( // IDENTIFICATION FOR SET1
        .tag_size(tag_size)
        ) 
    cache_identification_set_0(
        .tag(tag_input),
        .valid_mem(valid_out_s1),
        .tag_mem(tag_out_s1),
        .hit(hit_s1)
        );

    Cache_identification#( // IDENTIFICATION FOR SET2
        .tag_size(tag_size)
        ) 
    cache_identification_set_1(
        .tag(tag_input),
        .valid_mem(valid_out_s2),
        .tag_mem(tag_out_s2),
        .hit(hit_s2)
        );

    Cache_replacement_data#( 
        .idx_size(idx_size),
        .block_no(block_no)
        ) 
    cache_replacement_inst(
        .clk(clk),
        .rst(rst),
        .read(read),
        .write(write),
        .idx(idx_input),
        .hit_s1(hit_s1),
        .hit_s2(hit_s2),
        .write_L2(write_L2),
        .write_through(write_through),
        .valid_out_s1(valid_out_s1),
        .valid_out_s2(valid_out_s2),
        .we_s1(we_s1),
        .we_s2(we_s2)
        );

    Cache_output_set_select #( 
        .block_size(block_size)
        )
    Cache_output_set_select_inst(
        .hit(hit),
        .cache_set_output_select(cache_set_output_select),
        .data_out_s2(data_out_s2),
        .data_out_s1(data_out_s1),
        .data_block(data_block)
        );

    Cache_LOAD_L1_data #(
        .offset_size(offset_size),
        .word_size(word_size),
        .block_size(block_size),
        .data_width(data_width)
        )
    Cache_LOAD_L1_data_inst(
        .data_block(data_block),
        .offset(offset_input),
        .word(word_input),
        .data(data)
        );

    Cache_STORE_L1_data#(
        .offset_size(offset_size),
        .word_size(word_size),
        .block_size(block_size),
        .data_width(data_width)
        )
    Cache_STORE_L1_data_inst(
        .write_L2(write_L2),
        .data_L2(data_L2),
        .write_data(write_data),
        .write_strobe(write_strobe),
        .offset(offset_input),
        .word(word_input),
        .byte_enable_h(byte_enable_h),
        .byte_enable_l(byte_enable_l),
        .data_in_write(data_in_write)
        );
endmodule
