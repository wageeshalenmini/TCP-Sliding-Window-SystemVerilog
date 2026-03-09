`timescale 1ns/1ps

module packet_sender (
    input  logic clk, rst,
    input  logic [415:0] s_axis_tdata,
    input  logic          s_axis_tvalid,
    output logic          s_axis_tready,
    output logic [63:0]  m_axis_tdata,
    output logic          m_axis_tvalid,
    input  logic          m_axis_tready,
    output logic          m_axis_tlast
);
    logic [3:0]  count;
    logic [447:0] buffer;
    logic [31:0] tx_crc;

    crc32_calc crc_inst (.data_in(s_axis_tdata), .crc_out(tx_crc));

    assign s_axis_tready = (count == 0);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin m_axis_tvalid <= 0; m_axis_tlast <= 0; count <= 0; end
        else begin
            if (s_axis_tvalid && s_axis_tready) begin
                buffer <= {s_axis_tdata, tx_crc};
                m_axis_tdata <= s_axis_tdata[415:352];
                m_axis_tvalid <= 1; m_axis_tlast <= 0; count <= 1;
            end else if (count > 0 && m_axis_tready) begin
                m_axis_tdata <= buffer[(447 - count*64) -: 64];
                m_axis_tvalid <= 1;
                m_axis_tlast <= (count == 6);
                if (count == 6) count <= 0; else count <= count + 1;
            end else if (m_axis_tready) begin
                m_axis_tvalid <= 0; m_axis_tlast <= 0;
            end
        end
    end
endmodule