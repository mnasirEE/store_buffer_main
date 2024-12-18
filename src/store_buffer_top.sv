// Copyright 2023 University of Engineering and Technology Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: The Store Buffer module. 
//
// Author: M.Faisal Shahkar & M.Nasir, UET Lahore
// Date: 17.12.2024

// `ifndef VERILATOR
// `include "../defines/cache_defs.svh"
// `else
// `include "cache_defs.svh"
// `endif

module store_buffer_top #(
    parameter ADDR_WIDTH     = 32,
    parameter DATA_WIDTH     = 32,
    parameter BYTE_SEL_WIDTH = 4,
    parameter FIFO_DEPTH     = 4,
    parameter BLEN           = 4
)
(
    input  logic                      clk,                        // Clock
    input  logic                      rst_n,                      // Reset, active low

    // LSU --> store_buffer_top
    input  logic [ADDR_WIDTH-1:0]     lsudbus2stb_addr,         // Address from LSU
    input  logic [DATA_WIDTH-1:0]     lsudbus2stb_wdata,       // Write data from LSU
    input  logic [BYTE_SEL_WIDTH-1:0] lsudbus2stb_sel_byte,     // Byte select from LSU
    input  logic                      lsudbus2stb_w_en,               // Write enable 
    input  logic                      lsudbus2stb_req,
    input  logic                      dmem_sel_i,

    // store_buffer_top --> LSU
    output logic                      stb2dbuslsu_ack,
    output logic                      stb2dbuslsu_stall,

    // store_buffer_top --> dcache
    output logic [ADDR_WIDTH-1:0]     stb2dcache_addr,
    output logic [DATA_WIDTH-1:0]     stb2dcache_wdata,
    output logic [BYTE_SEL_WIDTH-1:0] stb2dcache_sel_byte,
    output logic                      stb2dcache_w_en,
    output logic                      stb2dcache_req,
    // output logic                        dmem_sel_o,
    
    output logic                      stb2dcache_empty,           // store buffer empty signal to dcache
    output logic                      dmem_sel_o,                 // Data memory select from Store Buffer

    // dCache --> store_buffer_top  
    input logic                       dcache2stb_ack
);

// define signals

logic stb_empty;
logic stb_full;
logic stb_initial_read;
logic stb_ack;
logic stb_wr_en;
logic stb_r_en;
logic stb_stall;
logic cache_write_ack;
logic rd_sel;
/* =========================================== Store Buffer Datapath ==================================== */
assign rd_sel = 1'b1;
datapath #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BYTE_SEL_WIDTH(BYTE_SEL_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_datapath             (.clk(clk),
                            .rst_n(rst_n),
                            .lsudbus2stb_addr(lsudbus2stb_addr),
                            .lsudbus2stb_wdata(lsudbus2stb_wdata),
                            .lsudbus2stb_sel_byte(lsudbus2stb_sel_byte),
                            .wr_en(stb_wr_en),
                            .r_en(stb_r_en),
                            .rd_sel(rd_sel),
                            .stb_empty(stb_empty),
                            .stb_full(stb_full),
                            .stb2dcache_addr(stb2dcache_addr),
                            .stb2dcache_wdata(stb2dcache_wdata),
                            .stb2dcache_sel_byte(stb2dcache_sel_byte),
                            .stb2dcache_w_en(stb2dcache_w_en),
                            .stb2dcache_req(stb2dcache_req));

/* =========================================== Store Buffer Controller ==================================== */
    stb_controller stb_main_controller (.clk(clk),
                                    .rst_n(rst_n),
                                    .dmem_sel_i(dmem_sel_i),
                                    .lsudbus2stb_w_en(lsudbus2stb_w_en),
                                    .lsudbus2stb_req(lsudbus2stb_req),
                                    .stb_full(stb_full),
                                    .stb_empty(stb_empty),
                                    .cache_write_ack(cache_write_ack),
                                    .stb_wr_en(stb_wr_en),
                                    .stb_r_en(stb_r_en),
                                    .stb_initial_read(stb_initial_read),
                                    .stb_ack(stb_ack),
                                    .stb_stall(stb_stall));


assign stb2dcache_empty  = stb_empty;  
assign stb2dbuslsu_ack   = stb_ack;
assign stb2dbuslsu_stall = stb_stall; 

// logic for read operation 

always_comb begin : read_logic
    if(!rst_n) begin
        cache_write_ack = 0;
    end
    else if (stb_initial_read) begin
        cache_write_ack = 1;
    end
    else if (dcache2stb_ack) begin
        cache_write_ack = 1;
    end
    else begin
        cache_write_ack = cache_write_ack;
    end
end

endmodule
