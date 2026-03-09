`timescale 1ns/1ps

module tb_top;
    import tcp_defs::*;
    logic clk=0, rst, start_conn, drop_pkt=0;
    
    // Fixed names to match tcp_engine ports for .* connection
    logic m_axis_tx_tvalid;
    logic m_axis_tx_tready;
    tcp_header_t m_eng_header;
    logic [255:0] m_eng_payload;
    
    logic [63:0] bus_tdata;
    logic bus_tvalid, bus_tlast;
    logic rx_packet_done, rx_is_new, rx_crc_err;
    tcp_header_t rx_header;
    logic [255:0] rx_payload;

    byte msg_buffer[128]; int msg_ptr = 0;
    logic corrupt_enable = 0;
    logic [63:0] bus_tdata_maybe_corrupt;
    assign bus_tdata_maybe_corrupt = (corrupt_enable && bus_tvalid) ? (bus_tdata ^ 64'hDEAD) : bus_tdata;

    always #5 clk = ~clk;

    // The .* will now find m_axis_tx_tvalid and m_axis_tx_tready
    tcp_engine engine (
        .clk, .rst, .start_connection(start_conn), 
        .m_axis_tx_tvalid, .m_axis_tx_tready,
        .m_axis_tx_tdata_payload(m_eng_payload), 
        .m_axis_tx_tdata_header(m_eng_header), 
        .s_axis_rx_tvalid((rx_packet_done && !drop_pkt)), 
        .s_axis_rx_tdata_header(rx_header), 
        .s_axis_rx_tuser_err(rx_crc_err && !drop_pkt)
    );

    packet_sender sender (
        .clk, .rst, 
        .s_axis_tdata({m_eng_header, m_eng_payload}), 
        .s_axis_tvalid(m_axis_tx_tvalid), 
        .s_axis_tready(m_axis_tx_tready), 
        .m_axis_tdata(bus_tdata), .m_axis_tvalid(bus_tvalid), 
        .m_axis_tready(1'b1), .m_axis_tlast(bus_tlast)
    );

    packet_receiver receiver (
        .clk, .rst, 
        .s_axis_tdata(bus_tdata_maybe_corrupt), 
        .s_axis_tvalid(bus_tvalid), .s_axis_tlast(bus_tlast), 
        .header_out(rx_header), .payload_out(rx_payload), 
        .packet_valid(rx_packet_done), .is_new_data(rx_is_new), 
        .checksum_err(rx_crc_err)
    );

    always @(negedge clk) begin
        if (rx_packet_done && rx_is_new) begin
            for (int i=31; i>=0; i--) 
                if (rx_payload[i*8 +: 8] != 0) 
                    msg_buffer[msg_ptr++] = byte'(rx_payload[i*8 +: 8]);
        end
    end

    initial begin
        $display("\n========= STARTING REPAIRED SIMULATION =========\n");
        rst = 1; #100 rst = 0;
        #100 start_conn = 1; #20 start_conn = 0;
        wait(rx_packet_done && !rx_crc_err); @(posedge clk);
        drop_pkt = 1; #3000; drop_pkt = 0;
        #2000; @(posedge bus_tvalid); @(posedge clk); corrupt_enable = 1; @(posedge clk); corrupt_enable = 0;
        wait(engine.state == engine.DONE); #500;
        $write("FINAL MESSAGE: "); for (int j=0; j < msg_ptr; j++) $write("%c", msg_buffer[j]); $display("");
        $display("\n========= SIMULATION SUCCESS =========");
        $finish;
    end
endmodule