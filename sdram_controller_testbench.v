module sdram_controller_testbench();

reg clk;
reg clk_90_degree;
reg rst = 0;

initial begin
	clk = 0;
	clk_90_degree = 0;
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
	#9 clk <= !clk;
end

always @* begin
	clk_90_degree <= #4 clk;
end


reg [3:0] state = 0;
reg [4:0] burst_left = 1;

always @(posedge clk) begin
	case(state)
		0: begin
			rst <= 1;
			// Load to first (0) bank, first row, first
			dbus_address <= {13'b0000000000000,2'b00,9'b000000000, 1'b0};
			dbus_writedata <= 16'h5555;
			dbus_byteenable <= 2'b11;
			dbus_burstcount <= 1;
			dbus_read <= 0;
			dbus_write <= 1;
			if(!dbus_waitrequest) begin
				state <= 1;
				dbus_address <= {13'b0000000000000,2'b01,9'b000000000, 1'b0};
				dbus_byteenable <= 2'b10;
			end
		end
		1: begin
			dbus_address <= {13'b0000000000000,2'b01,9'b000000000, 1'b0};
			if(!dbus_waitrequest) begin
				state <= 2;
				dbus_write <= 0;
				dbus_read <= 0;
				
			end
		end
		2: begin
			if(!dbus_write) begin
				dbus_write <= 1;
				dbus_address <= {13'b0000000000000,2'b01,9'b000001100, 1'b0};
				burst_left <= 8;
				dbus_burstcount <= 8;
				dbus_byteenable <= 2'b11;
			end
			if(dbus_write && !dbus_waitrequest) begin
				dbus_writedata <= dbus_writedata + 1;
				if(burst_left)
					burst_left <= burst_left - 1;
				else begin
					state <= 3;
					dbus_write <= 0;
					dbus_read <= 0;
				end
			end
		end
		3: begin
			if(!dbus_read) begin
				dbus_read <= 1;
				dbus_address <= {13'b0000000000000,2'b01,9'b000001100, 1'b0};
				burst_left <= 5;
				dbus_burstcount <= 5;
				dbus_byteenable <= 2'b11;
			end
			if(dbus_readdatavalid && !dbus_waitrequest) begin
				if(burst_left)
					burst_left <= burst_left - 1;
				
			end
			if(burst_left == 0) begin
				state <= 4;
				dbus_write <= 0;
				dbus_read <= 0;
			end
		end
		4: begin
			if(!dbus_read) begin
				dbus_read <= 1;
				dbus_address <= {13'b0000000000000,2'b01,9'b000001100, 1'b0};
				dbus_burstcount <= 1;
				dbus_byteenable <= 2'b11;
			end
			if(dbus_read && dbus_readdatavalid) begin
				
				state <= 5;
				dbus_write <= 0;
				dbus_read <= 0;
			end
		end
		5: begin
		
		end
	endcase
end



sdram_controller u0(

	.clk(clk),
	.rst(rst),
	
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