// Copyright 2023 University of Engineering and Technology Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: The Store Buffer module. 
//
// Author: M.Faisal Shahkar & M.Nasir, UET Lahore
// Date: 17.12.2024

// store_buffer_fifo datapath (.clk(clk),
//                             .rst_n(rst_n),
//                             .lsudbus2stb_addr(lsudbus2stb_addr),
//                             .lsudbus2stb_wdata(lsudbus2stb_wdata),
//                             .lsudbus2stb_sel_byte(lsudbus2stb_sel_byte),
//                             .wr_en(),
//                             .rd_sel(),
//                             .stb_empty(),
//                             .stb_full(),
//                             .stb2dcache_addr(stb2dcache_addr),
//                             .stb2dcache_wdata(stb2dcache_wdata),
//                             .stb2dcache_sel_byte(stb2dcache_sel_byte),
//                             .stb2dcache_w_en(stb2dcache_w_en),
//                             .stb2dcache_req(stb2dcache_req));

module datapath #(
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 32,
    parameter BYTE_SEL_WIDTH    = 4,
    parameter FIFO_DEPTH        = 4
)

(
    input  logic                        clk,
    input  logic                        rst_n,

    // Write interface (from LSU)
    input  logic [ADDR_WIDTH -1:0]   lsudbus2stb_addr,         // Address from LSU
    input  logic [DATA_WIDTH - 1:0]     lsudbus2stb_wdata,       // Write data from LSU
    input  logic [BYTE_SEL_WIDTH - 1:0] lsudbus2stb_sel_byte,     // Byte select from LSU
    input  logic  wr_en,               // Write enable 
    input  logic  rd_sel,
    input  logic  r_en,
    input  logic  dcache2stb_ack,


    output logic stb_empty,              // FIFO empty signal
    output logic stb_full,               // FIFO full signal

    // Data outputs (to DCache)
    output logic [ADDR_WIDTH-1:0]     stb2dcache_addr,
    output logic [DATA_WIDTH-1:0]        stb2dcache_wdata,
    output logic [BYTE_SEL_WIDTH-1:0]    stb2dcache_sel_byte
       
);

    // Parameters
    // parameter FIFO_DEPTH = 4;  // Reduced for simplicity in simulation

    // FIFO structure
    typedef struct packed {
        logic [ADDR_WIDTH-1:0]           addr;
        logic [DATA_WIDTH-1:0]           wdata;
        logic [BYTE_SEL_WIDTH-1:0]       sel_byte;
    } fifo_entry_t;

    fifo_entry_t fifo_mem[FIFO_DEPTH]; // FIFO memory
    logic [$clog2(FIFO_DEPTH)-1:0]       wr_ptr, rd_ptr; // Write and read pointers
    logic [$clog2(FIFO_DEPTH):0]                 entry_count;  // Count of entries in the FIFO


    // Write logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            // entry_count <= 0;
        end else if (wr_en && !stb_full) begin
            fifo_mem[wr_ptr].addr     <= lsudbus2stb_addr;
            fifo_mem[wr_ptr].wdata    <= lsudbus2stb_wdata;
            fifo_mem[wr_ptr].sel_byte <= lsudbus2stb_sel_byte;
            wr_ptr <= (wr_ptr + 1) % FIFO_DEPTH;  // Wrap-around logic
        end
    end

    // // Read logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
        end else if (r_en) begin
            // stb2dcache_addr <= fifo_mem[rd_ptr].addr;
            // stb2dcache_wdata <= fifo_mem[rd_ptr].wdata;
            // stb2dcache_sel_byte <= fifo_mem[rd_ptr].sel_byte;
            rd_ptr <= (rd_ptr + 1) % FIFO_DEPTH;  // Wrap-around logic
        
        end
    end

    // Entry count for FIFO
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            entry_count = 0;
        end
        else if (wr_en) begin
            entry_count = entry_count + 1;
        end
        else if (dcache2stb_ack) begin
            entry_count = entry_count - 1;
        end
        else begin
            entry_count = entry_count;
        end
        // stb_empty = (entry_count == 0);
        // stb_full = (entry_count == FIFO_DEPTH);
    end
    
    always_comb begin
        if (rd_sel) begin
            stb2dcache_addr     = fifo_mem[rd_ptr].addr;
            stb2dcache_wdata    = fifo_mem[rd_ptr].wdata;
            stb2dcache_sel_byte = fifo_mem[rd_ptr].sel_byte;
            // stb2dcache_w_en     = 1'b1;
            // stb2dcache_req      = 1'b1;
        end else begin
            stb2dcache_addr      = 0;
            stb2dcache_wdata     = 0;
            stb2dcache_sel_byte  = 0;
            // stb2dcache_w_en      = 1'b0;
            // stb2dcache_req       = 1'b0;
        end
    end

     // Status signals
    // assign stb_empty = (entry_count == 0);
    // assign stb_full = (entry_count == FIFO_DEPTH);
    always_ff @(posedge clk or negedge rst_n) begin : empty_full_logic
    if (!rst_n) begin
        stb_empty <= 1;
        stb_full  <= 0;
    end else begin
        // Update stb_empty and stb_full based on entry_count
        if (entry_count == 0) begin
            stb_empty <= 1;
            stb_full  <= 0;
        end else if (entry_count == FIFO_DEPTH+1) begin
            stb_empty <= 0;
            stb_full  <= 1;
        end else begin
            stb_empty <= 0;
            stb_full  <= 0;
        end
    end
end


    // assign stb_full = (entry_count == 2'b11);

endmodule