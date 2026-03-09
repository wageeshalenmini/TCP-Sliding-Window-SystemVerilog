`timescale 1ns/1ps

module crc32_calc (
    input  logic [415:0] data_in,
    output logic [31:0]  crc_out
);
    logic [31:0] crc;
    logic [7:0] byte_val;
    always_comb begin
        crc = 32'hFFFFFFFF;
        for (int i = 51; i >= 0; i--) begin
            byte_val = data_in[i*8 +: 8];
            crc = crc ^ {24'h0, byte_val};
            for (int b = 0; b < 8; b++) begin
                if (crc[0]) crc = (crc >> 1) ^ 32'hEDB88320;
                else        crc = crc >> 1;
            end
        end
        crc_out = crc ^ 32'hFFFFFFFF;
    end
endmodule