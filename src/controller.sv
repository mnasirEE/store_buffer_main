// Copyright 2023 University of Engineering and Technology Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: The Store Buffer module. 
//
// Author: M.Faisal Shahkar & M.Nasir, UET Lahore
// Date: 17.12.2024

module stb_controller (
    input  logic clk,
    input  logic rst_n,
    input  logic dmem_sel_i,         // data memory selection signal
    input  logic lsudbus2stb_w_en,   // lsu         -> dbus -> stb - write enable
    input  logic lsudbus2stb_req,    // lsu         -> dbus -> stb - write or store request 
    input  logic stb_full,           // datapath    -> controller  - store buffer full 
    input  logic stb_empty,          // datapath    -> controller  - store buffer empty
    input  logic cache_write_ack,    // cache       -> stb_top     - cache_ack
    output logic stb_wr_en,          // controller  -> datapath    - write enable for write stb counter
    output logic stb_r_en,           // controller  -> datapath    - read enable for stb read counter
    output logic stb_initial_read,   // controller  -> datapath    - initial read or initial write to cache when we are not waiting for cache ack
    output logic stb_ack,            // controller  -> stb_top     - ack signal after writing data successfully in store buffer
    output logic stb_stall           // controller  -> stb_top     - stall signal if buffer full

);

typedef enum logic [1:0] {
    IDLE  = 2'b00,
    WRITE = 2'b01,
    READ  = 2'b11
} state_type;

// define current and next states
state_type current_state, next_state;

// current state logic 

always_ff @( posedge clk or negedge rst_n ) begin : current_state_logic
    if (!rst_n) 
        begin
            current_state <= IDLE;
        end 
    else 
        begin
            current_state <= next_state;
        end
end

// next state logic 

always_comb begin : next_state_logic
    case (current_state)
        IDLE: begin
            if (dmem_sel_i && lsudbus2stb_w_en && lsudbus2stb_req && !stb_full) begin
                next_state = WRITE;
            end
            else begin
                next_state = IDLE;
            end
        end
        WRITE: begin
            if (dmem_sel_i && lsudbus2stb_w_en && lsudbus2stb_req && !stb_full || stb_empty) begin
                next_state = WRITE;
            end
            else if (cache_write_ack && !stb_empty) begin
                next_state = READ;
            end
            else if (cache_write_ack && !stb_empty && stb_full) begin
                next_state = READ;
            end
            else if (!dmem_sel_i && !lsudbus2stb_w_en && !lsudbus2stb_req && !stb_full && stb_empty) begin
                next_state = IDLE;
            end
            else begin
                next_state = WRITE;
            end
        end
        READ: begin
            if (dmem_sel_i && lsudbus2stb_w_en && lsudbus2stb_req && !stb_full) begin
                next_state = WRITE;
            end
            else begin
                next_state = WRITE;
            end
        end
        default: next_state = IDLE;
    endcase
end


// output logic 

always_comb begin : output_logic
    case (current_state)
        IDLE: begin
            if (dmem_sel_i && lsudbus2stb_w_en && lsudbus2stb_req && !stb_full ) begin
                stb_wr_en        = 1'b1;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b1;
                stb_ack          = 1'b0;        
                stb_stall        = 1'b0;      
            end
            else begin
                stb_wr_en        = 1'b0;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b0;
                stb_ack          = 1'b0;        
                stb_stall        = 1'b0;
            end
        end 
        WRITE: begin
            stb_ack =1'b1;
            if (dmem_sel_i && lsudbus2stb_w_en && lsudbus2stb_req && !stb_full || stb_empty) begin
                stb_wr_en        = 1'b1;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b0;
                // stb_ack          = 1'b0;        
                stb_stall        = 1'b0;
            end
            else if (cache_write_ack && !stb_empty) begin
                stb_wr_en        = 1'b0;      
                stb_r_en         = 1'b1;       
                stb_initial_read = 1'b0;
                // stb_ack          = 1'b0;        
                stb_stall        = 1'b0;
            end
            else if (cache_write_ack && !stb_empty && stb_full) begin
                stb_wr_en        = 1'b0;      
                stb_r_en         = 1'b1;       
                stb_initial_read = 1'b0;
                // stb_ack          = 1'b0;        
                stb_stall        = 1'b1;
            end
            else if (!dmem_sel_i && !lsudbus2stb_w_en && !lsudbus2stb_req && !stb_full && stb_empty) begin
                stb_wr_en        = 1'b0;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b0;
                // stb_ack          = 1'b0;        
                stb_stall        = 1'b0;
            end
            else begin
                stb_wr_en        = 1'b0;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b0;
                // stb_ack          = 1'b0;        
                stb_stall        = 1'b0;
            end
        end
        READ: begin
            if (dmem_sel_i && lsudbus2stb_w_en && lsudbus2stb_req && !stb_full) begin
                stb_wr_en        = 1'b1;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b0;
                // stb_ack          = 1'b0;        
                stb_stall        = 1'b0;
            end
            else begin
                stb_wr_en        = 1'b0;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b0;
                // stb_ack          = 1'b0;        
                stb_stall        = 1'b0;
            end
        end
        default: begin
            stb_wr_en        = 1'b0;      
            stb_r_en         = 1'b0;       
            stb_initial_read = 1'b0;
            stb_ack          = 1'b0;        
            stb_stall        = 1'b0;
        end
    endcase
end
    
endmodule