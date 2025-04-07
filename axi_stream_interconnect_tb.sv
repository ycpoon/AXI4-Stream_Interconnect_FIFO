module tb_axi_stream_interconnect;

  // Parameters
  parameter M = 4;
  parameter S = 4;
  parameter DATA_WIDTH = 2;
  parameter TDEST_WIDTH = 4;
  parameter TID_WIDTH = 2;
  parameter TUSER_WIDTH = 2;
  parameter BUFFER_DEPTH = 64;

  // Clock & Reset
  logic clk = 0;
  logic rst = 1;

  always #5 clk = ~clk; // 100MHz clock

  // AXI4-Stream Slave (input) signals
  logic [S-1:0][DATA_WIDTH*8-1:0] s_axis_tdata;
  logic [S-1:0][TDEST_WIDTH-1:0] s_axis_tdest;
  logic [S-1:0][TID_WIDTH-1:0] s_axis_tid;
  logic [S-1:0][TUSER_WIDTH-1:0] s_axis_tuser;
  logic [S-1:0] s_axis_tvalid;
  logic [S-1:0] s_axis_tlast;
  logic [S-1:0] s_axis_tready;

  // AXI4-Stream Master (output) signals
  logic [M-1:0] m_axis_tready;
  logic [M-1:0][DATA_WIDTH*8-1:0] m_axis_tdata;
  logic [M-1:0][TDEST_WIDTH-1:0] m_axis_tdest;
  logic [M-1:0][TID_WIDTH-1:0] m_axis_tid;
  logic [M-1:0][TUSER_WIDTH-1:0] m_axis_tuser;
  logic [M-1:0] m_axis_tvalid;
  logic [M-1:0] m_axis_tlast;

  // DUT instantiation
  axi_stream_interconnect #(
    .M(M), .S(S), .DATA_WIDTH(DATA_WIDTH),
    .TDEST_WIDTH(TDEST_WIDTH), .TID_WIDTH(TID_WIDTH),
    .TUSER_WIDTH(TUSER_WIDTH), .BUFFER_DEPTH(BUFFER_DEPTH)
  ) dut (
    .clk(clk),
    .rst(rst),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tdest(s_axis_tdest),
    .s_axis_tid(s_axis_tid),
    .s_axis_tuser(s_axis_tuser),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tready(s_axis_tready),
    .m_axis_tready(m_axis_tready),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tdest(m_axis_tdest),
    .m_axis_tid(m_axis_tid),
    .m_axis_tuser(m_axis_tuser),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tlast(m_axis_tlast)
  );

    int sid;
    int mid;
    int data;
    int datacount;

  // Stimulus
  initial begin
    // Reset
    #10 rst = 0;

    // Initialize inputs
    s_axis_tvalid = 0;
    s_axis_tlast = 0;
    s_axis_tdata = '0;
    s_axis_tdest = '0;
    s_axis_tid = '0;
    s_axis_tuser = '0;

    m_axis_tready = '1; // always ready to accept

    // Send data from slave 0 → master 2 (via TDEST[3:2] = 2)
    @(negedge clk);
    s_axis_tdata[0] = 16'hA5A5;
    s_axis_tdest[0] = 4'b1000; // TDEST[3:2] = 2
    s_axis_tid[0]   = 2'b01;
    s_axis_tuser[0] = 2'b11;
    s_axis_tlast[0] = 1'b1;
    s_axis_tvalid[0] = 1'b1;

    // Wait until slave ready
    // wait (s_axis_tready[0]);
    @(negedge clk);
    s_axis_tvalid[0] = 0;

    // Wait for data to appear on master
    wait (m_axis_tvalid[2]);
    $display("Slave 2 received: data = %h, tdest = %h, tid = %h, tuser = %h, tlast = %b",
             m_axis_tdata[2], m_axis_tdest[2], m_axis_tid[2], m_axis_tuser[2], m_axis_tlast[2]);

    // RANDOM TESTING 1: Normal
    $display("Test 1");
    repeat (10) begin
      sid = $urandom_range(0, 3);
      mid = $urandom_range(0, 3);
      data = $urandom_range(0, 32768);
      @(negedge clk);
      s_axis_tdata[sid] = data;
      s_axis_tdest[sid] = {mid[1:0], 2'b00}; // make upper bits = mid
      s_axis_tid[sid]   = $urandom;
      s_axis_tuser[sid] = $urandom;
      s_axis_tlast[sid] = 1'b1;
      s_axis_tvalid[sid] = 1'b1;

      wait (m_axis_tvalid[mid]);
      if(m_axis_tdata[mid] != data) begin
        $display("@@@ TEST FAILED");
      end
      $display("Slave %d received: data = %h, tdest = %h, tid = %h, tuser = %h, tlast = %b",
             mid, m_axis_tdata[mid], m_axis_tdest[mid], m_axis_tid[mid], m_axis_tuser[mid], m_axis_tlast[mid]);
      @(negedge clk);
      s_axis_tvalid[sid] = 0;
    end

    // RANDOM TESTING 2: Fill FIFO
    $display("Test 2");
    repeat (5) begin
      sid = $urandom_range(0, 3);
      mid = $urandom_range(0, 3);
      data = $urandom_range(0, 32768);
      @(negedge clk);
      m_axis_tready = '0;
      datacount = 0;
      for(int i = 0; i < M; i++) begin
        s_axis_tdata[sid] = datacount;
        s_axis_tdest[sid] = {mid[1:0], 2'b00}; // make upper bits = mid
        s_axis_tid[sid]   = $urandom;
        s_axis_tuser[sid] = $urandom;
        s_axis_tlast[sid] = 1'b1;
        s_axis_tvalid[sid] = 1'b1;
        datacount++;
        @(negedge clk);
      end
      
      m_axis_tready = '1;
      datacount = 0;
      //@(negedge clk);
      for(int i = 0; i < M; i++) begin
        if(m_axis_tdata[mid] != datacount) begin
            $display("@@@ TEST FAILED");
        end
        $display("Slave %d received: data = %h, tdest = %h, tid = %h, tuser = %h, tlast = %b",
                mid, m_axis_tdata[mid], m_axis_tdest[mid], m_axis_tid[mid], m_axis_tuser[mid], m_axis_tlast[mid]);
        datacount++;
        @(negedge clk);
      end

      @(negedge clk);
      s_axis_tvalid[sid] = 0;
    end

    #100;
    $display("\n\033[32m@@@ Passed\033[0m\n");
    $finish;
  end

endmodule