// Copyright 2023 University of Engineering and Technology Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: The Store Buffer module. 
//
// Author: M.Faisal Shahkar & M.Nasir, UET Lahore
// Date: 17.12.2024

module store_buffer_fifo (
    input  logic clk,
    input  logic rst_n,

    // Write interface (from LSU)
    input  logic [7:0] lsummu2stb_addr,         // Address from LSU
    input  logic [15:0] lsummu2stb_wdata,       // Write data from LSU
    input  logic [3:0] lsummu2stb_sel_byte,     // Byte select from LSU
    input  logic wr_en,               // Write enable 
    input logic rd_sel,


    output logic stb_empty,              // FIFO empty signal
    output logic stb_full,               // FIFO full signal

    // Data outputs (to DCache)
    output logic [7:0] stb2dcache_addr,
    output logic [15:0] stb2dcache_wdata,
    output logic [3:0] stb2dcache_sel_byte
);

    // Parameters
    parameter FIFO_DEPTH = 4;  // Reduced for simplicity in simulation

    // FIFO structure
    typedef struct packed {
        logic [7:0] addr;
        logic [15:0] wdata;
        logic [3:0] sel_byte;
    } fifo_entry_t;

    fifo_entry_t fifo_mem[FIFO_DEPTH]; // FIFO memory
    logic [$clog2(FIFO_DEPTH)-1:0] wr_ptr, rd_ptr; // Write and read pointers
    logic [FIFO_DEPTH:0] entry_count;  // Count of entries in the FIFO


    // Write logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            entry_count <= 0;
        end else if (wr_en && !stb_full) begin
            fifo_mem[wr_ptr].addr <= lsummu2stb_addr;
            fifo_mem[wr_ptr].wdata <= lsummu2stb_wdata;
            fifo_mem[wr_ptr].sel_byte <= lsummu2stb_sel_byte;
            wr_ptr <= (wr_ptr + 1) % FIFO_DEPTH;  // Wrap-around logic
        end
    end

    // Read logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
        end else if (!wr_en && !stb_empty) begin
            stb2dcache_addr <= fifo_mem[rd_ptr].addr;
            stb2dcache_wdata <= fifo_mem[rd_ptr].wdata;
            stb2dcache_sel_byte <= fifo_mem[rd_ptr].sel_byte;
            rd_ptr <= (rd_ptr + 1) % FIFO_DEPTH;  // Wrap-around logic
        
        end
    end

    // Entry count for FIFO
    always_comb begin
        if (wr_en) begin
            entry_count = entry_count + 1;
        end
        else begin
            entry_count = entry_count - 1;
        end
        
    end
    
    always_comb begin
        if (rd_sel) begin
            stb2dcache_addr = fifo_mem[rd_ptr].addr;
            stb2dcache_wdata = fifo_mem[rd_ptr].wdata;
            stb2dcache_sel_byte = fifo_mem[rd_ptr].sel_byte;
        end else begin
            stb2dcache_addr = 0;
            stb2dcache_wdata = 0;
            stb2dcache_sel_byte = 0;
        end
    end

     // Status signals
    assign stb_empty = (entry_count == 0);
    assign stb_full = (entry_count == FIFO_DEPTH);

endmodule