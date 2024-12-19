// Copyright 2023 University of Engineering and Technology Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: The Store Buffer module. 
//
// Author: M.Faisal Shahkar & M.Nasir, UET Lahore
// Date: 17.12.2024


module tb_store_buffer_top;

    // Parameters
    parameter NUM_RAND_TESTS = 10;
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter BYTE_SEL_WIDTH = 4;
    parameter FIFO_DEPTH     = 4;
    parameter BLEN = 4;
    parameter BLEN_IDX = $clog2(BLEN);

    // DUT signals
    logic                       clk;
    logic                       rst_n;
    
    // LSU --> store_buffer_top
    logic [ADDR_WIDTH-1:0]      lsudbus2stb_addr;
    logic [DATA_WIDTH-1:0]      lsudbus2stb_wdata;
    logic [BYTE_SEL_WIDTH-1:0]  lsudbus2stb_sel_byte;
    logic                       lsudbus2stb_w_en;
    logic                       lsudbus2stb_req;
    logic                       dmem_sel_i;

    // store_buffer_top --> LSU
    logic                       stb2dbuslsu_stall;
    logic                       stb2dbuslsu_ack;       // Store Buffer acknowledges the write

    // dcache --> store_buffer_top
    logic                       dcache2stb_ack;

    // store_buffer_top --> dcache
    logic [ADDR_WIDTH-1:0]      stb2dcache_addr;
    logic [DATA_WIDTH-1:0]      stb2dcache_wdata;
    logic [BYTE_SEL_WIDTH-1:0]  stb2dcache_sel_byte;
    logic                       stb2dcache_w_en;      // Write enable from Store Buffer
    logic                       stb2dcache_req;       // Store request from Store Buffer
    logic                       stb2dcache_empty;
    logic                       dmem_sel_o;           // Data memory select from Store Buffer

    logic [DATA_WIDTH-1:0]      dcache2stb_rdata;
    logic [DATA_WIDTH-1:0]      stb2lsudbus_rdata;

    // monitor and queue signals
    logic [DATA_WIDTH-1:0] m_mem [0:BLEN-1];
    logic [BLEN_IDX-1:0]  m_wr_idx, m_rd_idx;

    // Instantiate the DUT (Device Under Test)
    store_buffer_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BYTE_SEL_WIDTH(BYTE_SEL_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .BLEN(BLEN)
    ) DUT (
        .clk                    (clk),
        .rst_n                  (rst_n),


        // LSU --> store_buffer_top
        .lsudbus2stb_addr        (lsudbus2stb_addr),
        .lsudbus2stb_wdata       (lsudbus2stb_wdata),
        .lsudbus2stb_sel_byte    (lsudbus2stb_sel_byte),
        .lsudbus2stb_w_en        (lsudbus2stb_w_en),
        .lsudbus2stb_req         (lsudbus2stb_req),
        .dmem_sel_i              (dmem_sel_i),

        // store_buffer_top --> LSU
        .stb2dbuslsu_stall       (stb2dbuslsu_stall),        
        .stb2dbuslsu_ack         (stb2dbuslsu_ack),

        // store_buffer_top --> dcache
        .stb2dcache_addr        (stb2dcache_addr),
        .stb2dcache_wdata       (stb2dcache_wdata),
        .stb2dcache_sel_byte    (stb2dcache_sel_byte),
        .stb2dcache_w_en        (stb2dcache_w_en),
        .stb2dcache_req         (stb2dcache_req),
        .stb2dcache_empty       (stb2dcache_empty),
        .dmem_sel_o             (dmem_sel_o),

        //dcache --> store_buffer_top
        .dcache2stb_ack         (dcache2stb_ack)

        // .dcache2stb_rdata       (dcache2stb_rdata),
        // .stb2lsudbus_rdata       (stb2lsudbus_rdata)
    );

     // Clock generation
    always #5 clk = ~clk;

    task init_sequence;
        clk                 = 0;
        rst_n               = 0;
        dmem_sel_i          = 0;
        lsudbus2stb_w_en     = 0;
        lsudbus2stb_req      = 0;
        dcache2stb_ack      = 0;
        // stb2dbuslsu_ack     = 0;
        // stb2dbuslsu_stall   = 0;

        lsudbus2stb_addr     = 32'b0;
        lsudbus2stb_wdata    = 32'b0;
        lsudbus2stb_sel_byte = 4'b1111;    
    endtask

    task reset_apply;
        rst_n = 0;
        @(posedge clk);
        rst_n = 1;    
    endtask  

    // Test stimulus
    initial begin
        // Initialize signals
        
        init_sequence();
        // Assert reset
        $display("Assert Reset");
        reset_apply();

        // Test 1: Normal Write Operation
        $display("Test 1: Normal Write Operation");
        
        write_to_buffer(32'h1000, 32'hAAAA_BBBB, 4'b1111);
        // write_to_buffer(32'h1004, 32'hCCCC_DDDD, 4'b1111);
        // write_to_buffer(32'h1008, 32'hBBBB_aaaa, 4'b1111);
        // write_to_buffer(32'h100c, 32'hffff_DDDD, 4'b1111);
        //write_to_buffer(32'h2000, 32'hAAAA_BBBB, 4'b1111);
        //write_to_buffer(32'h1004, 32'hCCCC_DDDD, 4'b1111);
        @(posedge clk);

        // Test 3: Write to Cache (Cache ready, Buffer not empty)
        // $display("Test 3: Write to Cache");
        // while (!stb2dcache_empty) begin
        //     write_to_cache();
        // end
        // @(posedge clk);
        
        // End the simulation
        $display("End of Simulation");
        $finish;
    end

    // Task to write to store buffer
    task write_to_buffer(
        input [ADDR_WIDTH-1:0] addr, 
        input [DATA_WIDTH-1:0] data, 
        input [BYTE_SEL_WIDTH-1:0] byte_sel
    );
        begin
            lsudbus2stb_addr         = addr;
            lsudbus2stb_wdata         = data;
            lsudbus2stb_sel_byte     = byte_sel;
            dmem_sel_i   = 1;
            lsudbus2stb_w_en         = 1;
            lsudbus2stb_req       = 1;  // actually valid signal
            @(posedge clk);
            while (!stb2dbuslsu_ack) begin // actually ready signal
                @(posedge clk);
                $display("action");
            end
            $display("action done");
            lsudbus2stb_w_en = 0;
            lsudbus2stb_req = 0;
            @(posedge clk);
            $display("reaction");
        end
    endtask

    logic [31:0]dcache[0:31];
    task write_to_cache();
        dcache2stb_ack = 0;
        @(posedge clk);
        while (!stb2dcache_req)   
            @(posedge clk);
        
        if (stb2dcache_w_en) begin
            dcache[stb2dcache_addr] = stb2dcache_wdata;
        end  
        dcache2stb_ack = 1;
        repeat(2)@(posedge clk);
        dcache2stb_ack = 0;   
    endtask

endmodule