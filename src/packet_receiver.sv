`timescale 1ns/1ps

module packet_receiver (
    input  logic clk, rst,
    input  logic [63:0]  s_axis_tdata,
    input  logic          s_axis_tvalid,
    input  logic          s_axis_tlast,
    output tcp_defs::tcp_header_t header_out,
    output logic [255:0] payload_out,
    output logic packet_valid, is_new_data,
    output logic checksum_err
);
    import tcp_defs::*;
    logic [447:0] shift_reg;
    logic [447:0] next_shift;
    logic [31:0] expected_seq;

    function automatic logic [31:0] calc_crc32(input logic [415:0] din);
        logic [31:0] c;
        logic [7:0] bv;
        c = 32'hFFFFFFFF;
        for (int i = 51; i >= 0; i--) begin
            bv = din[i*8 +: 8];
            c = c ^ {24'h0, bv};
            for (int b = 0; b < 8; b++) begin
                if (c[0]) c = (c >> 1) ^ 32'hEDB88320;
                else      c = c >> 1;
            end
        end
        return c ^ 32'hFFFFFFFF;
    endfunction

    tcp_header_t header_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            expected_seq <= 1; shift_reg <= 0;
            packet_valid <= 0; is_new_data <= 0; checksum_err <= 0;
            header_reg <= '0;
        end
        else begin
            packet_valid <= 0; is_new_data <= 0; checksum_err <= 0;
            if (s_axis_tvalid) begin
                next_shift = {shift_reg[383:0], s_axis_tdata};
                shift_reg <= next_shift;
                if (s_axis_tlast) begin
                    automatic logic [31:0] rx_crc = calc_crc32(next_shift[447:32]);
                    packet_valid <= 1;
                    header_reg <= next_shift[447:288];
                    header_reg.ack_num <= next_shift[415:384];
                    if (rx_crc != next_shift[31:0]) checksum_err <= 1;
                    else if (next_shift[415:384] == expected_seq) begin
                        is_new_data <= 1; expected_seq <= expected_seq + 1;
                    end
                end
            end
        end
    end
    assign header_out  = header_reg;
    assign payload_out = shift_reg[287:32];
endmodule