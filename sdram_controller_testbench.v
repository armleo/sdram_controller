`timescale 1ns/1ns
module sdram_controller_testbench();

reg clk;
reg clk_90_degree;
reg arst_n = 0;

initial begin
	clk = 0;
	clk_90_degree = 0;
	#1 arst_n = 1;
end

//


wire sdram_CLK, sdram_CKE, sdram_nCS, sdram_nRAS, sdram_nCAS, sdram_nWE;
wire [1:0] sdram_BA, sdram_DM;
wire [12:0] sdram_ADDR;
wire [15:0] sdram_DQ;

wire init_done;

reg   [24:0] 	dbus_address = 25'd0;
reg   [15:0] 	dbus_writedata = 16'd100;
wire  [15:0]	dbus_readdata;
reg   [1:0] 	dbus_byteenable = 2'b11;
reg   [6:0]		dbus_burstcount = 16;
reg 			dbus_read = 0,
				dbus_write = 0;
wire			dbus_waitrequest,
				dbus_readdatavalid;

initial begin
	$dumpfile(`SIMRESULT);
	$dumpvars;
	#`PERIODS
	$finish;
end

always begin
	#5 clk <= !clk;
end

always @* begin
	clk_90_degree <= #2 clk;
end


reg [3:0] state = 0;
reg [4:0] burst_left = 1;

always @* begin
	case(state)
		0: begin
			dbus_address = {13'b0000000000000,2'b00,9'b000000000, 1'b0};
			dbus_writedata = 16'hFFFF;
			dbus_byteenable = 2'b11;
			dbus_burstcount = 1;
			dbus_write = 1;
			dbus_read = 0;
		end
		1: begin
			dbus_address <= {13'b0000000000000,2'b01,9'b000000000, 1'b0};
			dbus_writedata = 16'h4444;
			dbus_byteenable = 2'b11;
			dbus_burstcount = 1;
			dbus_write = 1;
			dbus_read = 0;
		end
		2: begin
			dbus_address = {13'b0000000000000,2'b01,9'b000001100, 1'b0};
			dbus_writedata = 16'h4444;
			dbus_byteenable = 2'b11;
			dbus_burstcount = 8;
			dbus_write = 1;
			dbus_read = 0;
		end
		3: begin
			dbus_address = {13'b0000000000000,2'b01,9'b000001100, 1'b0};
			dbus_writedata = 16'h4444;
			dbus_byteenable = 2'b11;
			dbus_burstcount = 16;
			dbus_write = 0;
			dbus_read = 1;
		end
		4: begin
			dbus_address = {13'b0000000000000,2'b01,9'b000001100, 1'b0};
			dbus_writedata = 16'h4444;
			dbus_byteenable = 2'b11;
			dbus_burstcount = 1;
			dbus_write = 0;
			dbus_read = 1;
		end
		5: begin
			dbus_address = {13'b0000000000000,2'b01,9'b000001100, 1'b0};
			dbus_writedata = 16'h8677;
			dbus_byteenable = 2'b11;
			dbus_burstcount = 1;
			dbus_write = 1;
			dbus_read = 0;
		end
		default: begin
			dbus_address = {13'b0000000000000,2'b00,9'b000000000, 1'b0};
			dbus_read = 0;
			dbus_write = 0;
			dbus_burstcount = 1;
			dbus_byteenable = 2'b00;
			dbus_writedata = 16'h0000;
		end
	endcase
end


always @(posedge clk) begin
	case(state)
		0: begin
			if(!dbus_waitrequest) begin
				state <= 1;
			end
		end
		1: begin
			if(!dbus_waitrequest) begin
				state <= 2;
				burst_left <= 8 - 1;
			end
		end
		2: begin
			if(dbus_write && !dbus_waitrequest) begin
				if(burst_left)
					burst_left <= burst_left - 1;
				else begin
					state <= 3;
					burst_left <= 16 - 1;
				end
			end
		end
		3: begin
			if(dbus_read && dbus_readdatavalid && !dbus_waitrequest) begin
				if(burst_left)
					burst_left <= burst_left - 1;
				else begin
					state <= 4;
					burst_left <= 1;
				end
			end
		end
		4: begin
			if(dbus_read && dbus_readdatavalid && !dbus_waitrequest) begin
				state <= 5;
			end
		end
		5: begin
			if(dbus_write && !dbus_waitrequest) begin
				state <= 6;
			end
		end
	endcase
end



sdram_controller u0(

	.clk(clk),
	.arst_n(arst_n),
	
	.*
);

sdr u1(
	.Clk(sdram_CLK),
	.Cke(sdram_CKE),
	.Cs_n(sdram_nCS),
	.Ras_n(sdram_nRAS),
	.Cas_n(sdram_nCAS),
	.We_n(sdram_nWE),
	.Dqm(sdram_DM),
	.Dq(sdram_DQ),
	.Addr(sdram_ADDR),
	.Ba(sdram_BA)
);

endmodule