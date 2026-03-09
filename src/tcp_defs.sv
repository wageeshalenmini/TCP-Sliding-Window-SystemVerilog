`timescale 1ns/1ps

package tcp_defs;
    typedef struct packed {
        logic [15:0] src_port, dest_port;
        logic [31:0] seq_num, ack_num;
        logic [3:0]  data_offset, reserved;
        logic [7:0]  flags; 
        logic [15:0] window, checksum, urgent_ptr;
    } tcp_header_t;
endpackage