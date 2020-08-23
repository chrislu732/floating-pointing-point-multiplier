module fp_mult(A,B,clk,reset,C,done,flow);
    input [31:0] A,B;
    input clk;
    input reset;
    output [31:0] C;
    output done, flow;
    // state name
    parameter step1 = 3'b000;
    parameter step2 = 3'b001;
    parameter step3 = 3'b010;
    parameter step4 = 3'b011;
    parameter step5 = 3'b100;
    parameter step6 = 3'b101;
    parameter step7 = 3'b110;
    parameter step8 = 3'b111;
    parameter normal = 2'b00;
    parameter overflow = 2'b01;
    parameter underflow = 2'b10;
    
    reg [2:0] state;
    reg [1:0] r_flow;
    reg r_done;
    
    reg c1_out;
    reg [8:0] c2_out;
    reg [47:0] c3_out_b;
    reg [24:0] c3_out_s;
    
    reg [23:0] a_mult, b_mult;
    reg start;
    
    wire [47:0] c_mult;
    wire done_mult;
    
    wire a1_in = A[31];
    wire b1_in = B[31];
    wire [7:0] a2_in = A[30:23];
    wire [7:0] b2_in = B[30:23];
    wire [22:0] a3_in = A[22:0];
    wire [22:0] b3_in = B[22:0];
    
    assign flow = r_flow;
    assign done = r_done;
    assign C = {c1_out, c2_out[7:0], c3_out_s[22:0]};
    
    bit24_mult mult(a_mult, b_mult, clk, reset, start, c_mult, done_mult);
    
    always @(posedge clk)
    begin
        // initialize
        if (reset)
        begin
            r_flow <= 2'b00;
            r_done <= 1'b0;
            c1_out <= 1'b0;
            c2_out <= 9'b0;
            c3_out_s <= 25'b0;
            c3_out_b <= 48'b0;
            a_mult <= 24'b0;
            b_mult <= 24'b0;
            start <= 1'b0;
			state <= step1;
        end 
        else
        begin
            case (state)
                // underflow or not
                step1:
                begin
                    if (a2_in + b2_in < 127)
                    begin
                    r_flow <= 2'b10;
                    state <= step8;
                    end
                    else
                    begin
                    state <= step2;
                    end
                end
                // assignment inputs
                step2:
                begin
                    c1_out <= a1_in ^ b1_in;
                    c2_out <= a2_in + b2_in - 127;
                    a_mult <= {1'b1, a3_in};
                    b_mult <= {1'b1, b3_in};
                    start <= 1'b1;
                    state <= step3;
                end
                // assignment outputs
                step3:
                begin
                    if (done_mult)
                    begin
                        c3_out_b <= c_mult;
                        state <= step4;
                    end
                    start <= 1'b0;
                end
                // normalize
                step4:
                begin
                    if (c3_out_b[47])
                    begin
                        c3_out_b <= c3_out_b >> 1;
                        c2_out <= c2_out + 1;
                    end
                    state <= step5;
                end
                // overflow or not
                step5:
                begin
                    if (c2_out >= 255)
                    begin
		                r_flow <= 2'b01;
                        state <= step8;
                    end
                    else
                    begin
                        // round-off
                        if (c3_out_b[22])
                        begin
                            c3_out_s <= c3_out_b[47:23] + 1;
                            state <= step6;
                        end
                        else 
                        begin
                            c3_out_s <= c3_out_b[47:23];
                            state <= step7;
                        end
                    end
                end
                // ready to re-normalize
                step6: 
                begin
                    c3_out_b <= {c3_out_s, 23'b0};
                    state <= step4;
                end
                // done
                step7: r_done <= 1'b1;
                // exception handing
                step8:
                begin
                    c1_out <= 1'b0;
                    c2_out <= 9'b0;
                    c3_out_s <= 25'b0;
                    state <= step7;
                end
            endcase
        end
    end
endmodule

module bit24_mult(A,B,clk,reset,start,C,done);
    input [23:0] A,B;
    input clk;
    input start, reset;
    output [47:0] C;
    output done;
    // state name
    parameter step1 = 2'b00;
    parameter step2 = 2'b01;
    parameter step3 = 2'b10;
    
    reg [1:0] state;
    reg [5:0] counter;
    reg r_done;
    reg [47:0] r_c;
    
    reg [23:0] P, PA;
    
    reg[23:0] a_add, b_add;
    reg cin;
    
    wire [23:0] c_add;
    wire cout_add;
    
    assign C = r_c;
    assign done = r_done;
    
    bit24_select_adder adder(a_add, b_add, cin, c_add, cout_add);
    
    always@(posedge clk)
    begin
        // reset
        if (reset)
        begin
            counter <= 0;
            r_done <= 1'b0;
            P <= 24'b0;
            PA <= 24'b0;
            a_add <= 24'b0;
            b_add <= 24'b0;
            cin <= 1'b0;
            state <= step1;
        end
        else
        begin
            case (state)
                // initialze registers
                step1:
                begin
                    if (start)
                    begin
                    counter <= 0;
                    P <= 24'b0;
                    PA <= A;
                    state <= step2;
                    end
                end
                // assignment input and output
                step2:
                begin
                    if (counter == 24)
                    begin
                        r_c <= {P, PA};
                        r_done <= 1'b1;
                        state <= step1;
                    end
                    else
                    begin
                        counter <= counter + 1;
                        a_add <= {24{PA[0]}} & B;
                        b_add <= P[23:0];
                        state <= step3;
                    end
                end
                // assignment output of adder
                step3:
                begin
                    P <= {cout_add, c_add[23:1]};
                    PA <= {c_add[0], PA[23:1]};
                    state <= step2;
                end
            endcase
        end
    end
endmodule

module bit24_select_adder(A,B,CIN,C,COUT);
    input [23:0] A,B;
    input CIN;
    output [23:0] C;
    output COUT;
    wire [5:0] TC;
    bit4_select_adder adder1(A[3:0],B[3:0],C[3:0],CIN,TC[0]);
    bit4_select_adder adder2(A[7:4],B[7:4],C[7:4],TC[0],TC[1]);
    bit4_select_adder adder3(A[11:8],B[11:8],C[11:8],TC[1],TC[2]);
    bit4_select_adder adder4(A[15:12],B[15:12],C[15:12],TC[2],TC[3]);
    bit4_select_adder adder5(A[19:16],B[19:16],C[19:16],TC[3],TC[4]);
    bit4_select_adder adder6(A[23:20],B[23:20],C[23:20],TC[4],TC[5]);
    assign COUT = TC[5];
endmodule

module bit4_select_adder(A,B,C,CIN,COUT);
    input [3:0] A,B;
    input CIN;
    output [3:0] C;
    output COUT;
    wire COUTG,COUTV;
    wire [3:0] CG,CV;
    parameter GROUND = 1'b0;
    parameter VDD = 1'b1;
    bit4_adder adder1(A,B,CG,GROUND,COUTG);
    bit4_adder adder2(A,B,CV,VDD,COUTV);
    adder_mux mux1(CG[0],CV[0],CIN,C[0]);
    adder_mux mux2(CG[1],CV[1],CIN,C[1]);
    adder_mux mux3(CG[2],CV[2],CIN,C[2]);
    adder_mux mux4(CG[3],CV[3],CIN,C[3]);
    adder_mux mux5(COUTG,COUTV,CIN,COUT);
endmodule

module adder_mux(CG,CV,CIN,C);
    input CG,CV,CIN;
    output C;
    assign C = (CIN) ? CV : CG;
endmodule 
    

module bit4_adder(A,B,C,CIN,COUT);
    input [3:0] A,B;
    input CIN;
    output [3:0] C;
    output COUT;
    wire [2:0] TC;
    full_adder adder1(A[0],B[0],C[0],CIN,TC[0]);
    full_adder adder2(A[1],B[1],C[1],TC[0],TC[1]);
    full_adder adder3(A[2],B[2],C[2],TC[1],TC[2]);
    full_adder adder4(A[3],B[3],C[3],TC[2],COUT);
endmodule

module full_adder(A,B,C,CIN,COUT);
    input A,B,CIN;
    output C,COUT;
    assign C = A ^ B ^ CIN;
    assign COUT = (A & B) | (A & CIN) | (B & CIN);
endmodule
