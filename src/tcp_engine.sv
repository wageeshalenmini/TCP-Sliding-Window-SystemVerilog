`timescale 1ns/1ps

module tcp_engine (
    input  logic clk, rst, start_connection,
    output logic          m_axis_tx_tvalid,
    output logic [255:0] m_axis_tx_tdata_payload,
    output tcp_defs::tcp_header_t m_axis_tx_tdata_header,
    input  logic          m_axis_tx_tready,
    input  logic          s_axis_rx_tvalid,
    input  tcp_defs::tcp_header_t s_axis_rx_tdata_header,
    input  logic          s_axis_rx_tuser_err
);
    import tcp_defs::*;

    localparam TOTAL_SEGS  = 4;
    localparam WINDOW_SIZE = 2;

    typedef enum logic [2:0] {
        CLOSED, SYN_SENT, WAIT_SYNACK,
        FETCH_RAM, SEND_DATA, WINDOW_WAIT,
        DONE
    } state_t;

    state_t state;
    logic [2:0] send_next;
    logic [2:0] window_base;
    logic [3:0] fetch_cnt;
    logic [15:0] timeout_cnt;
    logic [6:0]  ram_addr;
    logic [31:0] ram_data;

    data_buffer_ram ram_inst (.clk, .addr(ram_addr), .data_out(ram_data));

    wire [2:0] in_flight = send_next - window_base;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= CLOSED;
            m_axis_tx_tvalid <= 0;
            send_next <= 0;
            window_base <= 0;
            fetch_cnt <= 0;
            ram_addr <= 0;
            timeout_cnt <= 0;
        end else begin
            case (state)
                CLOSED: if (start_connection) state <= SYN_SENT;

                SYN_SENT: begin
                    m_axis_tx_tdata_header <= '0;
                    m_axis_tx_tdata_header.flags <= 8'h02;
                    m_axis_tx_tvalid <= 1;
                    if (m_axis_tx_tvalid && m_axis_tx_tready) state <= WAIT_SYNACK;
                end

                WAIT_SYNACK: begin
                    m_axis_tx_tvalid <= 0;
                    if (s_axis_rx_tvalid) state <= FETCH_RAM;
                end

                FETCH_RAM: begin
                    if (fetch_cnt < 8) ram_addr <= (send_next * 8) + fetch_cnt;
                    if (fetch_cnt >= 2) m_axis_tx_tdata_payload <= {m_axis_tx_tdata_payload[223:0], ram_data};
                    if (fetch_cnt == 9) begin
                        fetch_cnt <= 0; state <= SEND_DATA;
                    end else fetch_cnt <= fetch_cnt + 1;
                end

                SEND_DATA: begin
                    m_axis_tx_tdata_header <= '0;
                    m_axis_tx_tdata_header.seq_num <= 32'(send_next + 1);
                    m_axis_tx_tdata_header.window  <= 16'(WINDOW_SIZE);
                    m_axis_tx_tdata_header.flags   <= 8'h10;
                    m_axis_tx_tvalid <= 1;

                    if (m_axis_tx_tvalid && m_axis_tx_tready) begin
                        m_axis_tx_tvalid <= 0;
                        send_next <= send_next + 1;
                        timeout_cnt <= 0;
                        if ((send_next + 1 - window_base) < WINDOW_SIZE && (send_next + 1) < TOTAL_SEGS)
                            state <= FETCH_RAM;
                        else state <= WINDOW_WAIT;
                    end
                end

                WINDOW_WAIT: begin
                    if (s_axis_rx_tvalid && !s_axis_rx_tuser_err) begin
                        automatic logic [31:0] ack_seq = s_axis_rx_tdata_header.ack_num;
                        if (ack_seq > {29'b0, window_base} && ack_seq <= TOTAL_SEGS) begin
                            window_base <= ack_seq[2:0];
                            timeout_cnt <= 0;
                            if (ack_seq == TOTAL_SEGS && send_next == TOTAL_SEGS) state <= DONE;
                            else if (send_next < TOTAL_SEGS) state <= FETCH_RAM;
                        end
                    end
                    else if (s_axis_rx_tvalid && s_axis_rx_tuser_err) begin
                        send_next <= window_base; timeout_cnt <= 0; state <= FETCH_RAM;
                    end
                    else if (timeout_cnt >= 500) begin
                        send_next <= window_base; timeout_cnt <= 0; state <= FETCH_RAM;
                    end
                    else timeout_cnt <= timeout_cnt + 1;
                end

                DONE: state <= DONE;
            endcase
        end
    end
endmodule