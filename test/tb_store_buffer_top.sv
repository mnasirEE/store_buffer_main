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
    parameter BLEN = 4;
    parameter BLEN_IDX = $clog2(BLEN);

    // DUT signals
    logic                       clk;
    logic                       rst_n;
    
    // LSU --> store_buffer_top
    logic [ADDR_WIDTH-1:0]      lsummu2stb_addr;
    logic [DATA_WIDTH-1:0]      lsummu2stb_wdata;
    logic [BYTE_SEL_WIDTH-1:0]  lsummu2stb_sel_byte;
    logic                       lsummu2stb_w_en;
    logic                       lsummu2stb_req;
    logic                       dmem_sel_i;

    // store_buffer_top --> LSU
    logic                       stb2lsummu_stall;
    logic                       stb2lsummu_ack;       // Store Buffer acknowledges the write

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
    logic [DATA_WIDTH-1:0]      stb2lsummu_rdata;

    // monitor and queue signals
    logic [DATA_WIDTH-1:0] m_mem [0:BLEN-1];
    logic [BLEN_IDX-1:0]  m_wr_idx, m_rd_idx;

    // Instantiate the DUT (Device Under Test)
    store_buffer_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BYTE_SEL_WIDTH(BYTE_SEL_WIDTH),
        .BLEN(BLEN)
    ) DUT (
        .clk                    (clk),
        .rst_n                  (rst_n),


        // LSU --> store_buffer_top
        .lsummu2stb_addr        (lsummu2stb_addr),
        .lsummu2stb_wdata       (lsummu2stb_wdata),
        .lsummu2stb_sel_byte    (lsummu2stb_sel_byte),
        .lsummu2stb_w_en        (lsummu2stb_w_en),
        .lsummu2stb_req         (lsummu2stb_req),
        .dmem_sel_i             (dmem_sel_i),

        // store_buffer_top --> LSU
        .stb2lsummu_stall       (stb2lsummu_stall),        
        .stb2lsummu_ack         (stb2lsummu_ack),

        // store_buffer_top --> dcache
        .stb2dcache_addr        (stb2dcache_addr),
        .stb2dcache_wdata       (stb2dcache_wdata),
        .stb2dcache_sel_byte    (stb2dcache_sel_byte),
        .stb2dcache_w_en        (stb2dcache_w_en),
        .stb2dcache_req         (stb2dcache_req),
        .stb2dcache_empty       (stb2dcache_empty),
        .dmem_sel_o             (dmem_sel_o),

        //dcache --> store_buffer_top
        .dcache2stb_ack         (dcache2stb_ack),

        .dcache2stb_rdata       (dcache2stb_rdata),
        .stb2lsummu_rdata       (stb2lsummu_rdata)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever begin
            clk = #5 ~clk;
        end
    end 

    task init_sequence;
        clk                 <= 0;
        rst_n               <= 0;
        dmem_sel_i          <= 0;
        lsummu2stb_w_en     <= 0;
        lsummu2stb_req      <= 0;
        dcache2stb_ack      <= 0;

        lsummu2stb_addr     <= 32'b0;
        lsummu2stb_wdata    <= 32'b0;
        lsummu2stb_sel_byte <= 4'b1111;    
    endtask

    task reset_apply;
        rst_n = 0;
        @(posedge clk);
        rst_n = 1;    
    endtask  

    // Test stimulus
    initial begin
        // Initialize signals
        $display("Initailize Signals\n");
        init_sequence;

        // Assert reset
        $display("Assert Reset\n");
        reset_apply;

        fork
            monitor;
            queue;
        join_none

        // Random Tests
        $display("Random Tests\n");
        fork
            lsu_driver;
            cache_driver;
        join

        // store buffer should be empty after all data write to cache
        repeat(2) @(posedge clk);
        $display("store buffer empty(1) or not(0): %b",stb2dcache_empty);
        
        // End the simulation
        $display("End of Simulation\n");
        $finish;
    end

    // Task to write to store buffer
    task lsu_driver;
        for(int i = 0; i<NUM_RAND_TESTS; i++) begin
            lsummu2stb_addr[4:0]    <= $urandom;
            lsummu2stb_wdata        <= $urandom;
            lsummu2stb_sel_byte     <= $urandom;
            dmem_sel_i              <= 1;
            lsummu2stb_w_en         <= 1;
            lsummu2stb_req          <= 1;
            @(posedge clk);
            while (stb2lsummu_stall)begin
                @(posedge clk);  
            end

            repeat(1)@(posedge clk);
            lsummu2stb_req          <= 0;
            if (lsummu2stb_w_en == 0) begin
                while (!stb2lsummu_ack) begin
                    @(posedge clk);
                end
                lsummu2stb_req          = 0;
                //@(posedge clk);
            end
            // else begin
            //     lsummu2stb_req          <= 0; 
            //     lsummu2stb_w_en         <= 0;
            //     while (!stb2lsummu_ack) begin
            //         @(posedge clk);
            //     end
            // end
            
        end
        lsummu2stb_addr[4:0]    <= 0;
        lsummu2stb_wdata        <= 0;
        lsummu2stb_sel_byte     <= 0;
        dmem_sel_i              <= 0;
        lsummu2stb_w_en         <= 0;
        lsummu2stb_req          <= 0;
    endtask

    task cache_driver;
        for(int i = 0; i<NUM_RAND_TESTS; i++) begin
            dcache2stb_ack <= 0;

            @(posedge clk);
            while (!stb2dcache_req)   
                @(posedge clk);
            
            repeat(2) @(posedge clk);
            // suppose that data cache send the ack after some cycles

            dcache2stb_rdata <= $urandom;
            dcache2stb_ack   <= 1;

            @(posedge clk);
            dcache2stb_rdata <= $urandom;
            dcache2stb_ack <= 0;
        end
    endtask

    // Writing the data in this temporary queue
    task queue;
        assign m_wr_idx = 0;
        while (1) begin
            @(posedge clk);
            if (lsummu2stb_w_en) begin
                if (!stb2lsummu_stall) begin
                    m_mem[m_wr_idx] = lsummu2stb_wdata;
                    assign m_wr_idx = (m_wr_idx == BLEN-1) ? '0: (m_wr_idx + 1);                
                end
            end 
        end
    endtask

    // Read the data from the queue and then compare it with store buffer output data
    task monitor;
        assign m_rd_idx = 0;
        while(1) begin
            @(posedge clk);
            if (stb2dcache_w_en) begin
            if (dcache2stb_ack) begin
                if (m_mem [m_rd_idx] != stb2dcache_wdata) begin
                    $display (">>> Test Failed :(");
                    $display ("m_rd_idx = %0h: lsummu2stb = %0h || stb2dcache = %0h \n",m_rd_idx, m_mem [m_rd_idx], stb2dcache_wdata);
                end else begin
                    $display ("Passed :)  <3");
                    $display ("m_rd_idx = %0h: lsummu2stb = %0h || stb2dcache = %0h \n",m_rd_idx, m_mem [m_rd_idx], stb2dcache_wdata);
                end
                assign m_rd_idx = (m_rd_idx == BLEN-1)? '0: (m_rd_idx + 1);
            end
            end
        end
    endtask

endmodule