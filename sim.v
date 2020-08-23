module sim();
  reg [31:0] A,B;
  reg clk = 0;
  reg reset = 1;
  wire [31:0] C;
  wire done, flow;
  fp_mult mult(A,B,clk,reset,C,done,flow);
  always #5 clk = ~clk;
  initial begin
      A = 32'h409224dd;
      B = 32'h4618a31f;
      #20 reset = 0;
  end
endmodule
