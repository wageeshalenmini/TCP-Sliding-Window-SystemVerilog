`timescale 1ns/1ps

module data_buffer_ram (
    input  logic clk,
    input  logic [6:0]  addr, 
    output logic [31:0] data_out
);
    logic [31:0] mem [0:127];
    initial begin
        for (int i=0; i<128; i++) mem[i] = 32'h0;
        mem[0] = 32'h50617274; mem[1] = 32'h5f312020; // Part_1
        mem[8] = 32'h50617274; mem[9] = 32'h5f322020; // Part_2
        mem[16]= 32'h50617274; mem[17]= 32'h5f332020; // Part_3
        mem[24]= 32'h50617274; mem[25]= 32'h5f342020; // Part_4
    end
    always_ff @(posedge clk) data_out <= mem[addr];
endmodule