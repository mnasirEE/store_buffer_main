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
    parameter NUM_RAND_TESTS = 105;
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
    logic [DATA_WIDTH-1:0]      stb2dbuslsu_rdata;

    // monitor and queue signals
    logic [DATA_WIDTH-1:0] m_mem [0:BLEN-1];
    logic [BLEN_IDX-1:0]  m_wr_idx, m_rd_idx;

    // test results
    integer tests_passed;
    integer tests_failed;
    integer total_tests;
    integer results_file; // File descriptor
    int     current_test;

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
        // .stb2dbuslsu_rdata       (stb2dbuslsu_rdata)
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
        lsudbus2stb_w_en     <= 0;
        lsudbus2stb_req      <= 0;
        dcache2stb_ack      <= 0;

        lsudbus2stb_addr     <= 32'b0;
        lsudbus2stb_wdata    <= 32'b0;
        lsudbus2stb_sel_byte <= 4'b1111; 
        tests_failed         <= 0;
        tests_passed         <= 0;
        total_tests          <= 0; 
        results_file         <= 0;  
        current_test         <= 1;
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

        results_file = $fopen("test/tests_results.txt", "w"); // Open file in write mode
        if (!results_file) begin
            $display("Error: Could not open tests_results.txt for writing.");
            $finish;
        end

        // monitor and temporary buffer
        /* This section starts two tasks (monitor and queue) in parallel.
           join_none ensures that these tasks run in the background and 
           do not block the main execution flow. This is important because 
           the main simulation continues without waiting for these tasks to complete.
        */
        fork
            monitor;
            queue;
            /* ensures that these tasks keep running in the background throughout 
               the simulation.
            */
        join_none 
        // Random Tests
        /* This section starts two tasks (lsu_driver and cache_driver) in parallel.
           join ensures that the simulation waits for both tasks to complete before 
           moving forward.
        */

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
        // display Tests results
        assign total_tests = tests_passed + tests_failed;
        $display("##################  Summary  ################\n");
        $display("Passed      = %0d", tests_passed);
        $display("Failed      = %0d", tests_failed);
        $display("Total Tests = %0d", total_tests);
        $fwrite(results_file, "\n");
        $fwrite(results_file, "##################  Summary  ################\n");
        $fwrite(results_file, "Total Passed = %0d\n", tests_passed);
        $fwrite(results_file, "Total Failed = %0d\n", tests_failed);
        $fwrite(results_file, "Total Tests = %0d\n",  total_tests);
        $finish;
    end

    // Task to write to store buffer
    task lsu_driver;
        for(int i = 0; i<NUM_RAND_TESTS; i++) begin
            lsudbus2stb_addr[4:0]    <= $urandom;
            lsudbus2stb_wdata        <= $urandom;
            lsudbus2stb_sel_byte     <= $urandom;
            dmem_sel_i              <= 1;
            lsudbus2stb_w_en         <= 1;
            lsudbus2stb_req          <= 1;
            @(posedge clk);
            while (stb2dbuslsu_stall)begin
                @(posedge clk);  
            end

            // repeat(1)@(posedge clk);
            lsudbus2stb_req          <= 0;
            if (lsudbus2stb_w_en == 0) begin
                while (!stb2dbuslsu_ack) begin
                    @(posedge clk);
                end
                lsudbus2stb_req          = 0;
                //@(posedge clk);
            end
            // else begin
            //     lsudbus2stb_req          <= 0; 
            //     lsudbus2stb_w_en         <= 0;
            //     while (!stb2dbuslsu_ack) begin
            //         @(posedge clk);
            //     end
            // end
            
        end
        lsudbus2stb_addr[4:0]    <= 0;
        lsudbus2stb_wdata        <= 0;
        lsudbus2stb_sel_byte     <= 0;
        dmem_sel_i              <= 0;
        lsudbus2stb_w_en         <= 0;
        lsudbus2stb_req          <= 0;
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
            if (lsudbus2stb_w_en) begin
                if (!stb2dbuslsu_stall) begin
                    m_mem[m_wr_idx] = lsudbus2stb_wdata;
                    assign m_wr_idx = (m_wr_idx == BLEN-1) ? '0: (m_wr_idx + 1);                
                end
            end 
        end
    endtask

    // Read the data from the queue and then compare it with store buffer output data
    task monitor();
        assign m_rd_idx = 0;
        while(1) begin
            @(posedge clk);
            if (stb2dcache_w_en) begin
            if (dcache2stb_ack) begin
                if (m_mem [m_rd_idx] != stb2dcache_wdata) begin
                    $display (">>> Test Failed :(");
                    $display ("m_rd_idx = %0h: lsudbus2stb = %0h || stb2dcache = %0h \n",
                               m_rd_idx, m_mem [m_rd_idx], stb2dcache_wdata);
                    $fwrite(results_file, "Test %0d Failed: Expected %h, Got %h at index %0d\n", 
                            current_test,m_mem[m_rd_idx], stb2dcache_wdata, m_rd_idx);
                    tests_failed++;
                end else begin
                    $display ("Passed :)  <3");
                    $display ("m_rd_idx = %0h: lsudbus2stb = %0h || stb2dcache = %0h \n",
                               m_rd_idx, m_mem [m_rd_idx], stb2dcache_wdata);
                    $fwrite(results_file, "Test %0d Passed: Data %h matches at index %0d\n", 
                            current_test,stb2dcache_wdata, m_rd_idx);
                    tests_passed++;
                end
                assign m_rd_idx = (m_rd_idx == BLEN-1)? '0: (m_rd_idx + 1);
                assign current_test = (current_test + 1) % NUM_RAND_TESTS;
            end
            end
        end
    endtask

endmodule