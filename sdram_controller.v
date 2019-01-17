`timescale 1ns/1ns

module sdram_controller(
	input 	wire 		clk,
	input	wire		rst,
	input	wire		clk_90_degree,
	
	output reg			init_done = 1,
	
	// Address for first word must be burst aligned:
	// So when burst is 8 words then 3 + 1 (word_size) least significant bits of address must be low at first access
	input	wire [ADDR_WIDTH-1:0]			dbus_address,
	input	wire [$clog2(BURST_MAX):0]		dbus_burstcount,
	
	input	wire 							dbus_read,
	output	reg 							dbus_readdatavalid,
	output	wire [(8 * BYTE_AMOUNT)-1:0]	dbus_readdata,
	
	input	wire							dbus_write,
	input	wire [(8 * BYTE_AMOUNT)-1:0]	dbus_writedata,
	input	wire [BYTE_AMOUNT-1:0]			dbus_byteenable,
	output	reg								dbus_waitrequest,
	
	output	wire							sdram_CLK,
	output	reg								sdram_CKE,
	output	wire							sdram_nCS,
	output	wire							sdram_nRAS,
	output	wire							sdram_nCAS,
	output	wire							sdram_nWE,
	output	reg  [BANK_WIDTH-1 		:0]		sdram_BA = {BANK_WIDTH{1'b0}},
	output	reg  [ROW_WIDTH-1  		:0]		sdram_ADDR = {ROW_WIDTH{1'd0}},
	output	reg  [BYTE_AMOUNT-1	:0]			sdram_DM,
	inout	wire [(8 * BYTE_AMOUNT)-1:0]	sdram_DQ
);

parameter CLK_TIME = 10;	// ns

parameter tRP = 18;				// ns
parameter tRFC = 66;			// ns
parameter tMRD = 2;				// CLK
parameter tREF = 64000000;		// ns
parameter tRCD = 18;			// ns

// Unchangeable
localparam tCAS = 2;			// CLK
// Unchangeable
localparam tWR = 2;				// CLK
// round up
localparam INIT_100US_DELAY_CKS = 100_000 / CLK_TIME;
localparam PRECHARGE_DELAY_CKS = (tRP + CLK_TIME) / CLK_TIME;
localparam AUTOREFRESH_DELAY_CKS = (tRFC + CLK_TIME) / CLK_TIME;
localparam MODE_REGISTER_DELAY_CKS = tMRD;
localparam ACTIVATE_DELAY_CKS = (tRCD + CLK_TIME) / CLK_TIME;
// round down
localparam REFRESH_CKS = (tREF / REFRESH_CYCLES - CLK_TIME) / CLK_TIME;
localparam REFRESH_CYCLES = 2**ROW_WIDTH;

parameter WORD_WIDTH	= 1;
parameter COL_WIDTH		= 9;
parameter BANK_WIDTH	= 2;
parameter ROW_WIDTH		= 13;
parameter BURST_MAX		= 64;


localparam ADDR_WIDTH   = WORD_WIDTH + COL_WIDTH + BANK_WIDTH + ROW_WIDTH;
localparam BYTE_AMOUNT  = 2**WORD_WIDTH;

localparam BANK_AMOUNT = 2**BANK_WIDTH;

/*
ADDR Structure
|13 |   2|	   9|   1|
|ROW|BANK|COLUMN|BYTE|
*/

reg [ADDR_WIDTH-1:0] r_dbus_address = 0;


wire [ROW_WIDTH-1:0] avl_row = r_dbus_address[WORD_WIDTH + COL_WIDTH + BANK_WIDTH + ROW_WIDTH - 1 : WORD_WIDTH + COL_WIDTH + BANK_WIDTH];
wire [BANK_WIDTH-1:0] avl_bank = r_dbus_address[WORD_WIDTH + COL_WIDTH + BANK_WIDTH - 1 : WORD_WIDTH + COL_WIDTH];
wire [COL_WIDTH-1:0] avl_col = r_dbus_address[WORD_WIDTH + COL_WIDTH - 1 : WORD_WIDTH];

localparam 	STATE_INIT_WAIT 				= 5'd0,
			STATE_NOP						= 5'd1,
			STATE_INIT_PRECHARGE_ALL 		= 5'd2,
			STATE_INIT_ISSUE_AUTOREFRESH_1 	= 5'd3,
			STATE_INIT_ISSUE_AUTOREFRESH_2 	= 5'd4,
			STATE_INIT_ISSUE_MRS			= 5'd5,
			STATE_IDLE						= 5'd6,
			STATE_CLOSE_ALL_BANKS			= 5'd7,
			STATE_AUTO_REFRESH				= 5'd8,
			STATE_ACTIVATE					= 5'd9,
			STATE_READ_BEGIN				= 5'd10,
			STATE_WRITE_BEGIN				= 5'd11,
			STATE_READ						= 5'd12,
			STATE_WRITE						= 5'd13,
			STATE_WRITE_BURST_STOP			= 5'd14
			;

reg [43*8:0] state_str;
always @* begin
	case(state)
		STATE_INIT_WAIT:
			state_str = "INIT_WAIT";
		STATE_NOP:
			state_str = "NOP";
		STATE_INIT_PRECHARGE_ALL:
			state_str = "INIT_PRECHARGE_ALL";
		STATE_INIT_ISSUE_AUTOREFRESH_1:
			state_str = "INIT_ISSUE_AUTOREFRESH_1";
		STATE_INIT_ISSUE_AUTOREFRESH_2:
			state_str = "INIT_ISSUE_AUTOREFRESH_2";
		STATE_INIT_ISSUE_MRS:
			state_str = "INIT_ISSUE_MRS";
		STATE_IDLE:
			state_str = "IDLE";
		STATE_CLOSE_ALL_BANKS:
			state_str = "CLOSE_ALL_BANKS";
		STATE_AUTO_REFRESH:
			state_str = "AUTO_REFRESH";
		STATE_ACTIVATE:
			state_str = "STATE_ACTIVATE";
		STATE_READ_BEGIN:
			state_str = "READ_BEGIN";
		STATE_WRITE_BEGIN:
			state_str = "WRITE_BEGIN";
		STATE_READ:
			state_str = "READ";
		STATE_WRITE:
			state_str = "WRITE";
		STATE_WRITE_BURST_STOP:
			state_str = "WRITE_BURST_STOP";
		default:
			state_str = "UNKNOWN STATE!!!";
	endcase
end

assign sdram_CLK = clk_90_degree;


// nCS, nRAS, nCAS, nWE
reg [3:0] command;
assign sdram_nCS = command[3];
assign sdram_nRAS = command[2];
assign sdram_nCAS = command[1];
assign sdram_nWE = command[0];


reg [8*12:0] cmd_str;
always @* begin
	case(command)
		COMMAND_NOP:
			cmd_str = "NOP         ";
		COMMAND_ACTIVE:
			cmd_str = "ACT         ";
		COMMAND_READ:
			cmd_str = "READ        ";
		COMMAND_WRITE:
			cmd_str = "WRITE       ";
		COMMAND_BST:
			cmd_str = "BST         ";
		COMMAND_PRECHARGE:
			cmd_str = "PRECHARGE   ";
		COMMAND_AUTOREFRESH:
			cmd_str = "AUTOREFRESH ";
		COMMAND_LMR:
			cmd_str = "LMR         ";
	endcase
end

localparam 	COMMAND_NOP = 4'b0111,
			COMMAND_ACTIVE = 4'b0011,
			COMMAND_READ = 4'b0101,
			COMMAND_WRITE = 4'b0100,
			COMMAND_BST = 4'b0110,
			COMMAND_PRECHARGE = 4'b0010,
			COMMAND_AUTOREFRESH = 4'b0001,
			COMMAND_LMR = 4'b0000
			;

// State machine
reg [4:0] state = STATE_INIT_WAIT;
reg [4:0] nxt_state = STATE_INIT_WAIT;

// Goes max to min
reg [15:0] delay_counter = 0;

// goes min to max and substracts REFRESH_CKS on overflow
reg refresh_counter_enable = 0;
reg [15:0] refresh_counter = 0;

// interface burst

reg [$clog2(BURST_MAX+1):0] burst_remaining = 0;



reg force_datamask;
reg command_burst_terminate_sent = 0; // for read

assign sdram_DQ = (state == STATE_WRITE || state == STATE_WRITE_BEGIN) ? dbus_writedata : {BYTE_AMOUNT*8{1'bZ}};

assign sdram_DM = (~dbus_byteenable) | {BYTE_AMOUNT{force_datamask}};

assign dbus_readdata = sdram_DQ;

always @* begin
	dbus_readdatavalid = 0;
	sdram_CKE = 1;
	sdram_BA = avl_bank;
	sdram_ADDR = {ROW_WIDTH{1'b0}};
	force_datamask = 0;
	command = COMMAND_NOP;
	dbus_waitrequest = 1;
	case (state)
		STATE_INIT_WAIT: begin
			sdram_CKE = 0;
			// without clock
			command = COMMAND_NOP;
			sdram_BA = 0;
		end
		STATE_INIT_PRECHARGE_ALL: begin
			command = COMMAND_PRECHARGE;
			sdram_ADDR[10] = 1'd1;
			force_datamask = 1;
			sdram_BA = 0;
			// sdram ADDR[10] high
		end
		STATE_INIT_ISSUE_AUTOREFRESH_1: begin
			command = COMMAND_AUTOREFRESH;
			sdram_BA = 0;
		end
		STATE_INIT_ISSUE_AUTOREFRESH_2: begin
			sdram_BA = 0;
			command = COMMAND_AUTOREFRESH;
		end
		STATE_INIT_ISSUE_MRS: begin
			sdram_BA = 0;
			command = COMMAND_LMR;
			sdram_ADDR = {
				1'b0,		// Programmed burst length
				2'b00,		// STD Operation
				3'b010,		// CAS Latency = 2
				4'b0111		// FULL Page Burst
			};
		end
		
		STATE_AUTO_REFRESH: begin
			command = COMMAND_AUTOREFRESH;
		end
		
		STATE_CLOSE_ALL_BANKS: begin
			command = COMMAND_PRECHARGE;
			force_datamask = 1;
			sdram_ADDR = {ROW_WIDTH{1'd1}};
			// precharge all banks
		end
		STATE_ACTIVATE: begin
			command = COMMAND_ACTIVE;
			sdram_ADDR = avl_row;
			sdram_BA = avl_bank;
		end
		STATE_WRITE_BEGIN: begin
			command = COMMAND_WRITE;
			sdram_ADDR = avl_col;
			sdram_BA = avl_bank;
			dbus_waitrequest = 0;
		end
		STATE_WRITE: begin
			dbus_waitrequest = 0;
			command = COMMAND_NOP;
		end
		STATE_WRITE_BURST_STOP: begin
			command = COMMAND_BST;
		end
		STATE_READ_BEGIN: begin
			command = COMMAND_READ;
			sdram_ADDR = avl_col;
			sdram_BA = avl_bank;
			dbus_readdatavalid = 0;
		end
		STATE_READ: begin
			dbus_readdatavalid = 1;
			dbus_waitrequest = 0;
			
			if(burst_remaining) begin
				command = COMMAND_NOP;
			end else if(!command_burst_terminate_sent) begin
				command = COMMAND_BST;
			end else begin
				command = COMMAND_NOP;
			end
		end
		STATE_IDLE: begin
			dbus_waitrequest = (dbus_read || dbus_write);
			command = COMMAND_NOP;
		end
		default: begin
			command = COMMAND_NOP;
		end
	endcase
end 



always @(posedge clk or negedge rst) begin
	if(!rst) begin
		delay_counter <= 0;
		state <= STATE_INIT_WAIT;
		refresh_counter_enable <= 0;
		refresh_counter <= 0;
		init_done <= 0;
	end else begin
		if(refresh_counter_enable) begin
			refresh_counter <= refresh_counter + 16'd1;
		end
		case (state)
			STATE_NOP: begin
				if(delay_counter > 0)
					delay_counter <= delay_counter - 1;
				else
					state <= nxt_state;
			end
			STATE_INIT_WAIT: begin
				state <= STATE_NOP;
				nxt_state <= STATE_INIT_PRECHARGE_ALL;
				delay_counter <= INIT_100US_DELAY_CKS - 1;
			end
			STATE_INIT_PRECHARGE_ALL: begin
				state <= STATE_NOP;
				nxt_state <= STATE_INIT_ISSUE_AUTOREFRESH_1;
				delay_counter <= PRECHARGE_DELAY_CKS - 1;
			end
			STATE_INIT_ISSUE_AUTOREFRESH_1: begin
				state <= STATE_NOP;
				nxt_state <= STATE_INIT_ISSUE_AUTOREFRESH_2;
				delay_counter <= AUTOREFRESH_DELAY_CKS - 1;
			end
			STATE_INIT_ISSUE_AUTOREFRESH_2: begin
				state <= STATE_NOP;
				nxt_state <= STATE_INIT_ISSUE_MRS;
				delay_counter <= AUTOREFRESH_DELAY_CKS - 1;
			end
			STATE_INIT_ISSUE_MRS: begin
				state <= STATE_NOP;
				nxt_state <= STATE_IDLE;
				delay_counter <= MODE_REGISTER_DELAY_CKS - 1;
				refresh_counter <= 0;
				refresh_counter_enable <= 1;
			end
			STATE_IDLE: begin
				init_done <= 1;
				if(refresh_counter >= REFRESH_CKS) begin
					state <= STATE_AUTO_REFRESH;
				end else if(dbus_read) begin
					state <= STATE_ACTIVATE;
					nxt_state <= STATE_READ_BEGIN;
					burst_remaining <= dbus_burstcount;
					r_dbus_address <= dbus_address;
				end else if(dbus_write) begin
					state <= STATE_ACTIVATE;
					nxt_state <= STATE_WRITE_BEGIN;
					burst_remaining <= dbus_burstcount;
					r_dbus_address <= dbus_address;
				end
			end
			STATE_CLOSE_ALL_BANKS: begin
				state <= STATE_NOP;
				nxt_state <= STATE_IDLE;
				delay_counter <= PRECHARGE_DELAY_CKS - 1;
			end
			STATE_AUTO_REFRESH: begin
				refresh_counter <= refresh_counter - REFRESH_CKS;
				delay_counter <= AUTOREFRESH_DELAY_CKS - 1;
				state <= STATE_NOP;
				nxt_state <= STATE_IDLE;
			end
			STATE_ACTIVATE: begin
				state <= STATE_NOP;
				delay_counter <= ACTIVATE_DELAY_CKS - 1;
			end
			STATE_WRITE_BEGIN: begin
				if(burst_remaining == 1)
					state <= STATE_WRITE_BURST_STOP;
				else begin
					state <= STATE_WRITE;
					burst_remaining <= burst_remaining - 1;
				end
			end
			STATE_WRITE: begin
				if(burst_remaining > 1) begin
					burst_remaining <= burst_remaining - 1;
				end else begin
					state <= STATE_WRITE_BURST_STOP;
				end
			end
			STATE_WRITE_BURST_STOP: begin
				state <= STATE_NOP;
				delay_counter <= tWR - 1;
				nxt_state <= STATE_CLOSE_ALL_BANKS;
			end
			STATE_READ_BEGIN: begin
				// read data valid low, 2 cycles
				burst_remaining <= burst_remaining - 2;
				state <= STATE_NOP;
				nxt_state <= STATE_READ;
				delay_counter <= tCAS - 1 - 1;
			end
			STATE_READ: begin
				burst_remaining
				// read data valid high burst_remaining - 2 cycles
				// on last cycle send burst stop
			end
			STATE_READ_BURST_STOP: begin
				// 2 last cycles read data valid high if data still reading
				state <= STATE_CLOSE_ALL_BANKS;
			end
		endcase
	end
end


endmodule