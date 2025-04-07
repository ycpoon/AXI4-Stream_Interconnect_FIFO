// AXI4-Stream Interconnect, Support up to 4 Master Ports and 4 Slave Ports
// Data Buffer available for Each Slave Ports, Read in FIFO
// Note: Slave Interfaces in this context refers to the input interface of the interconnect (connected to the master ports, Master Interface refers to the output interface (connected to the slave ports)

module axi_stream_interconnect #(
  parameter M = 4,          // Number of Master Interfaces or Number of Slave Ports, option: 1,2,3,4
  parameter S = 4, 			// Number of Slave Interfaces or Number of Master Ports, option: 1,2,3,4
  parameter DATA_WIDTH = 2,     // Data Width (in byte), option: 1-8
  parameter TDEST_WIDTH = 4,    // TDEST Width, the 2 MSB are used for interconnect routing
  parameter TID_WIDTH = 2,		// TID Width, option: 0-16
  parameter TUSER_WIDTH = 2,    // TUSER Width, option: 0-16
  parameter BUFFER_DEPTH = 64  // Storage size for data buffer
)(
  
  input clk,
  input rst,
  
  // Slave Interfaces (Connected to Master Ports)
  input [S-1:0][DATA_WIDTH*8-1:0] s_axis_tdata,
  input [S-1:0][TDEST_WIDTH-1:0] s_axis_tdest,
  input [S-1:0][TID_WIDTH-1:0]  s_axis_tid,
  input [S-1:0][TUSER_WIDTH-1:0]  s_axis_tuser,
  input [S-1:0] s_axis_tvalid,
  input [S-1:0] s_axis_tlast,
  output logic [S-1:0] s_axis_tready,
  
  // Master Interfaces (Connected to Slave Ports)
  input [M-1:0] m_axis_tready,
  output logic [M-1:0][DATA_WIDTH*8-1:0] m_axis_tdata,
  output logic [M-1:0][TDEST_WIDTH-1:0] m_axis_tdest,
  output logic [M-1:0][TID_WIDTH-1:0] m_axis_tid,
  output logic [M-1:0][TUSER_WIDTH-1:0] m_axis_tuser,
  output logic [M-1:0] m_axis_tvalid,
  output logic [M-1:0] m_axis_tlast
  
);

  typedef struct packed {
    logic [DATA_WIDTH*8-1:0] tdata;
    logic [TDEST_WIDTH-1:0] tdest;
    logic [TID_WIDTH-1:0] tid;
    logic [TUSER_WIDTH-1:0] tuser;
    logic tlast;
  } ENTRY_PACKET;

  ENTRY_PACKET [S-1:0] input_packet;
  ENTRY_PACKET [M-1:0] output_packet;

  logic [M-1:0][S-1:0] fifo_request;
  logic [M-1:0][S-1:0] fifo_gnt;
  logic [M-1:0] fifo_empty_req;
  logic [M-1:0][$clog2(S)-1:0] master_idx;
  logic [M-1:0] wr_valid, rd_valid;

  always_comb begin
    for(int i = 0; i < S; i++) begin
      input_packet[i].tdata = s_axis_tdata[i];
      input_packet[i].tdest = s_axis_tdest[i];
      input_packet[i].tid = s_axis_tid[i];
      input_packet[i].tuser = s_axis_tuser[i];
      input_packet[i].tlast = s_axis_tlast[i];
    end
  end

  always_comb begin
    fifo_request = '0;
    for(int i = 0; i < S; i++) begin
      if(s_axis_tvalid[i]) begin
        fifo_request[s_axis_tdest[i][TDEST_WIDTH-1 -: $clog2(M)]][i] = 1'b1;
      end
    end
  end

  genvar k;
  generate
    for(k = 0; k < M; k++) begin
      psel_gen #(
        .WIDTH(S),
        .REQS(1)
      ) pg1 (
        .req(fifo_request[k]),
        .gnt(fifo_gnt[k]),
        .empty(fifo_empty_req[k])
      );

      encoder #(
        .INPUT_LENGTH(S),
        .OUTPUT_LENGTH($clog2(S))
      ) e1 (
        .in(fifo_gnt[k]),
        .out(master_idx[k])
      );

      FIFO #(
        .DEPTH(BUFFER_DEPTH),
        .WIDTH($bits(ENTRY_PACKET))
      ) f1 (
        .clock(clk),
        .reset(rst),
        .wr_en(!fifo_empty_req[k]),
        .rd_en(m_axis_tready[k]),
        .wr_data(input_packet[master_idx[k]]),
        .wr_valid(wr_valid[k]),
        .rd_valid(rd_valid[k]),
        .rd_data(output_packet[k])
      );
    end
  endgenerate


  always_comb begin
    s_axis_tready = '0;
    for(int i = 0; i < M; i++) begin
      s_axis_tready[master_idx[i]] = !wr_valid[i] ? 0 : 1'b1;
    end
  end

  always_comb begin
    for(int i = 0; i < M; i++) begin
      m_axis_tvalid[i] = rd_valid[i];
      m_axis_tdata[i] = output_packet[i].tdata;
      m_axis_tdest[i] = output_packet[i].tdest;
      m_axis_tid[i] = output_packet[i].tid;
      m_axis_tuser[i] = output_packet[i].tuser;
      m_axis_tlast[i] = output_packet[i].tlast;
    end
  end

  
endmodule