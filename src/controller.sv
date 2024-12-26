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
    output logic stb2dbuslsu_ack,            // controller  -> stb_top     - ack signal after writing data successfully in store buffer
    output logic stb_stall,           // controller  -> stb_top     - stall signal if buffer full
    output logic stb_initial_done,
    input  logic dcache2stb_ack,
    output logic read_req_en
    // output logic stb_req,
    // output logic rd_sel,
    // output logic stb_w_en,
    // output logic dmem_sel

);

typedef enum logic [1:0] {
    IDLE  = 2'b00,
    WRITE = 2'b01,
    READ  = 2'b10,
    FULL_READ = 2'b11
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
        /* 1. if reset then we stay on idle
           2. if write or store instruction and buffer not full 
              then we move to WRITE state
           3. if write or store instruction but buffer full 
              then we move to FULL_READ state    
           */ 
        IDLE: begin
            if (dmem_sel_i && lsudbus2stb_w_en && lsudbus2stb_req && !stb_full) begin
                next_state = WRITE;
            end
            else begin
                next_state = IDLE;
            end
        end
        WRITE: begin
            /* if there is WRITE state and there write request and there is 
               also ack from dcache then stay on write means prefer write on next read
            */
            if (dmem_sel_i && lsudbus2stb_w_en && lsudbus2stb_req && !stb_full && dcache2stb_ack ) begin
                next_state = WRITE;
            end
            /* if there is WRITE state and there write request 
               then stay on WRITE for further write operation 
            */
            else if (dmem_sel_i && lsudbus2stb_w_en && lsudbus2stb_req && !stb_full) begin
                next_state = WRITE;
            end
            /* if there is WRITE state and there is not write 
            */
            // else if (dcache2stb_ack) begin
            //     next_state = WRITE;
            // end
            /* if buffer is full for first time after reset or when we come from idle 
               and buffer becomes full without read operation
               then move to FULL_READ state which reads or write to dcache whole data
            */
            else if (cache_write_ack && !stb_empty && stb_full) begin
                next_state = FULL_READ;
            end
            // if buffer becomes full goto READ_FULL TO write whole data to dcache
            else if (!stb_empty && stb_full) begin
                next_state = FULL_READ;
            end
            /* if there is ack from dcache and there is no write request
               and also buffer has some date or buffer is not empty goto 
               READ STATE to read or write data to dcache
            
            */
            else if (cache_write_ack && !stb_empty && dcache2stb_ack) begin
                next_state = READ;
            end
            /* if there is no write request and also buffer has some date 
               or buffer is not empty goto READ STATE to read or write data 
               to dcache
            */
            else if (cache_write_ack && !stb_empty) begin
                next_state = READ;
            end
            /* if buffer becomes empty goto IDLE STATE
            */
            else if (!dmem_sel_i && !lsudbus2stb_w_en && !lsudbus2stb_req && !stb_full && stb_empty) begin
                next_state = IDLE;
            end
            /* else stay on write or stay on write state if there is no write
               or read request but buffer is not empty nor full
            */
            else begin
                next_state = WRITE;
            end
        end
        FULL_READ: begin
            /* if buffer not becomes empty stay on FULL_READ STATE
            */
            if(!stb_empty) begin
                next_state = FULL_READ;
            end
            // if buffer becomes empty goto IDLE STATE
            else begin
                next_state = IDLE;
            end
        end
        READ: begin
            /* if there is write request goto WRITE STATE to write data to buffer
            */
            if (dmem_sel_i && lsudbus2stb_w_en && lsudbus2stb_req && !stb_full) begin
                next_state = WRITE;
            end
            /* if there is write request and there dcahe ack again prefer to write 
               operation, So goto WRITE STATE
            */
            else if (dmem_sel_i && lsudbus2stb_w_en && lsudbus2stb_req && !stb_full && dcache2stb_ack) begin
                next_state = WRITE;
            end
            // else if (dcache2stb_ack) begin
            //     next_state = WRITE;
            // end
            // else at any condition again goto WRITE STATE
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
        /* 1. if reset then we stay on idle
           2. if write or store instruction and buffer not full 
              then we move to WRITE state
           3. if write or store instruction but buffer full 
              then we move to FULL_READ state    

           */ 
        IDLE: begin
            if (dmem_sel_i && lsudbus2stb_w_en && lsudbus2stb_req && !stb_full ) begin
                stb_wr_en        = 1'b1;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b1;
                stb2dbuslsu_ack          = 1'b0;        
                stb_stall        = 1'b0; 
                stb_initial_done = 1'b0; 
                read_req_en      = 0;
                // stb_req          = 0;
                // rd_sel           = 0;
                // stb_w_en         = 0;
                // dmem_sel         = 0; 
            end
            else begin
                stb_wr_en        = 1'b0;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b0;
                stb2dbuslsu_ack          = 1'b0;        
                stb_stall        = 1'b0;
                stb_initial_done = 1'b0;
                read_req_en      = 0;
                // stb_req          = 0;
                // rd_sel           = 0;
                // stb_w_en         = 0;
                // dmem_sel         = 0; 
            end
        end 
        WRITE: begin
            stb2dbuslsu_ack =1'b1;
            if (dmem_sel_i && lsudbus2stb_w_en && lsudbus2stb_req && !stb_full && dcache2stb_ack ) begin
                stb_wr_en        = 1'b1;      
                stb_r_en         = 1'b1;       
                stb_initial_read = 1'b0;
                // stb2dbuslsu_ack          = 1'b0;        
                stb_stall        = 1'b0;
                stb_initial_done = 1'b0;
                read_req_en      = 0;
                // stb_req          = 0;
                // rd_sel           = 0;
                // stb_w_en         = 0;
                // dmem_sel         = 0; 
            end
            else if (dmem_sel_i && lsudbus2stb_w_en && lsudbus2stb_req && !stb_full) begin
                stb_wr_en        = 1'b1;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b0;
                // stb2dbuslsu_ack          = 1'b0;        
                stb_stall        = 1'b0;
                stb_initial_done = 1'b0;
                read_req_en      = 0;
                // stb_req          = 0;
                // rd_sel           = 0;
                // stb_w_en         = 0;
                // dmem_sel         = 0; 
            end
            // else if (dcache2stb_ack) begin
            //     stb_wr_en        = 1'b0;      
            //     stb_r_en         = 1'b1;       
            //     stb_initial_read = 1'b0;
            //     // stb2dbuslsu_ack          = 1'b0;        
            //     stb_stall        = 1'b0;
            //     stb_initial_done = 1'b0;
            //     read_req_en      = 0;
            //     // stb_req          = 0;
            //     // rd_sel           = 0;
            //     // stb_w_en         = 0;
            //     // dmem_sel         = 0; 
            // end
            else if (cache_write_ack && !stb_empty && stb_full) begin
                stb_wr_en        = 1'b0;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b0;
                // stb2dbuslsu_ack          = 1'b0;        
                stb_stall        = 1'b1;
                stb_initial_done = 1'b0;
                read_req_en      = 1;
            end
            else if (!stb_empty && stb_full) begin
                stb_wr_en        = 1'b0;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b0;
                // stb2dbuslsu_ack          = 1'b0;        
                stb_stall        = 1'b1;
                stb_initial_done = 1'b0;
                read_req_en      = 1;
            end
            else if (cache_write_ack && !stb_empty && dcache2stb_ack) begin
                stb_wr_en        = 1'b0;      
                stb_r_en         = 1'b1;       
                stb_initial_read = 1'b0;
                // stb2dbuslsu_ack          = 1'b0;        
                stb_stall        = 1'b0;
                stb_initial_done = 1'b0;
                read_req_en      = 1;
                // stb_req          = 0;
                // rd_sel           = 0;
                // stb_w_en         = 0;
                // dmem_sel         = 0; 
            end
            else if (cache_write_ack && !stb_empty) begin
                stb_wr_en        = 1'b0;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b0;
                // stb2dbuslsu_ack          = 1'b0;        
                stb_stall        = 1'b0;
                stb_initial_done = 1'b0;
                read_req_en      = 1;
                // stb_req          = 1;
                // rd_sel           = 1;
                // stb_w_en         = 1;
                // dmem_sel         = 1; 
            end
            // else if (cache_write_ack && !stb_empty && stb_full && !dcache2stb_ack) begin
            //     stb_wr_en        = 1'b0;      
            //     stb_r_en         = 1'b0;       
            //     stb_initial_read = 1'b0;
            //     // stb2dbuslsu_ack          = 1'b0;        
            //     stb_stall        = 1'b1;
            //     stb_initial_done = 1'b0;
            //     read_req_en      = 1;
            //     // stb_req          = 1;
            //     // rd_sel           = 1;
            //     // stb_w_en         = 1;
            //     // dmem_sel         = 1; 
                
            // end
            
            else if (!dmem_sel_i && !lsudbus2stb_w_en && !lsudbus2stb_req && !stb_full && stb_empty) begin
                stb_wr_en        = 1'b0;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b0;
                // stb2dbuslsu_ack          = 1'b0;        
                stb_stall        = 1'b0;
                stb_initial_done = 1'b0;
                read_req_en      = 0;
                // stb_req          = 0;
                // rd_sel           = 0;
                // stb_w_en         = 0;
                // dmem_sel         = 0; 
            end
            else begin
                stb_wr_en        = 1'b0;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b0;
                // stb2dbuslsu_ack          = 1'b0;        
                stb_stall        = 1'b0;
                stb_initial_done = 1'b0;
                read_req_en      = 0;
                // stb_req          = 0;
                // // rd_sel           = 0;
                // stb_w_en         = 0;
                // dmem_sel         = 0; 
            end
        end
        FULL_READ: begin
            // stb_initial_done = 1'b1;
            if(!stb_empty) begin
                if (dcache2stb_ack) begin
                    stb_wr_en        = 1'b0;      
                    stb_r_en         = 1'b1;       
                    stb_initial_read = 1'b0;
                    // stb2dbuslsu_ack          = 1'b0;        
                    stb_stall        = 1'b1;
                    stb_initial_done = 1'b0;
                    read_req_en      = 0;
                end
                else begin
                    stb_wr_en        = 1'b0;      
                    stb_r_en         = 1'b0;       
                    stb_initial_read = 1'b0;
                    // stb2dbuslsu_ack          = 1'b0;        
                    stb_stall        = 1'b1;
                    stb_initial_done = 1'b0;
                    read_req_en      = 1;
                end
                
            end
            else begin
                stb_wr_en        = 1'b0;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b0;
                // stb2dbuslsu_ack          = 1'b0;        
                stb_stall        = 1'b1;
                stb_initial_done = 1'b0;
                read_req_en      = 0;
            end
        end
        READ: begin
            stb_initial_done = 1'b1;
            if (dmem_sel_i && lsudbus2stb_w_en && lsudbus2stb_req && !stb_full) begin
                stb_wr_en        = 1'b1;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b0;
                stb2dbuslsu_ack          = 1'b0;        
                stb_stall        = 1'b0;
                read_req_en      = 0;
                // stb_req          = 0;
                // // rd_sel           = 0;
                // stb_w_en         = 0;
                // dmem_sel         = 0; 
            end
            else if (dmem_sel_i && lsudbus2stb_w_en && lsudbus2stb_req && !stb_full && dcache2stb_ack) begin
                stb_wr_en        = 1'b1;      
                stb_r_en         = 1'b1;       
                stb_initial_read = 1'b0;
                stb2dbuslsu_ack          = 1'b0;        
                stb_stall        = 1'b0;
                read_req_en      = 0;
                // stb_req          = 0;
                // // rd_sel           = 0;
                // stb_w_en         = 0;
                // dmem_sel         = 0; 
            end
            else if (dcache2stb_ack) begin
                stb_wr_en        = 1'b0;      
                stb_r_en         = 1'b1;       
                stb_initial_read = 1'b0;
                stb2dbuslsu_ack          = 1'b0;        
                stb_stall        = 1'b0;
                read_req_en      = 0;
                // stb_req          = 0;
                // // rd_sel           = 0;
                // stb_w_en         = 0;
                // dmem_sel         = 0; 
            end
            else begin
                stb_wr_en        = 1'b0;      
                stb_r_en         = 1'b0;       
                stb_initial_read = 1'b0;
                stb2dbuslsu_ack          = 1'b0;        
                stb_stall        = 1'b0;
                read_req_en      = 0;
                // stb_req          = 1;
                // // rd_sel           = 1;
                // stb_w_en         = 1;
                // dmem_sel         = 1; 
            end
        end
        default: begin
            stb_wr_en        = 1'b0;      
            stb_r_en         = 1'b0;       
            stb_initial_read = 1'b0;
            stb2dbuslsu_ack          = 1'b0;        
            stb_stall        = 1'b0;
            stb_initial_done = 1'b0;
            read_req_en      = 0;
            // stb_req          = 0;
            // // rd_sel           = 0;
            // stb_w_en         = 0;
            // dmem_sel         = 0;
            
        end
    endcase
end
    
endmodule