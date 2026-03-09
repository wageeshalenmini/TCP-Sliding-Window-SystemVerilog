# TCP Sliding Window Engine (SystemVerilog)

This project implements a simplified **TCP/IP transport layer engine** in SystemVerilog. It features a robust sliding window mechanism for reliable data transmission over potentially lossy or corrupt network interfaces.

## 🚀 Key Features
* **Sliding Window Protocol:** Implements a Window Size of 2 (W=2) with sequence tracking.
* **Reliability:** Includes **Go-Back-N** retransmission logic triggered by timeouts or NACKs.
* **Error Detection:** Integrated **CRC-32 (IEEE 802.3)** hardware calculator for frame integrity.
* **Interface:** Uses **AXI-Stream** inspired signaling for modular integration.
* **Testbench:** A comprehensive self-checking testbench that simulates packet loss and bit corruption.

## 🛠️ Project Structure
* `tcp_defs.sv`: Common structures and TCP header definitions.
* `tcp_engine.sv`: The main FSM controlling connection and retransmissions.
* `packet_sender.sv / packet_receiver.sv`: Logic for framing and CRC verification.
* `crc32_calc.sv`: Combinatorial CRC-32 logic.
* `data_buffer_ram.sv`: Simulated memory for data storage.

## 📊 Simulation Results
The design was verified using **ModelSim**. The simulation demonstrates:
1.  **Successful SYN/ACK Handshake.**
2.  **Automatic Retransmission** after a simulated timeout.
3.  **CRC Error Detection** followed by a successful recovery.
4.  **Perfect Message Reconstruction** of "Part_1 Part_2 Part_3 Part_4".