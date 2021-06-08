# UART实现

UART实际上就是一个每次时钟跳变沿都输出当前TX-FIFO内一位数据的多计数器设备

下面是两个简化的UART设计

### TX-UART

```verilog
`timescale 1ns/1ps

//系统时钟200MHz
//波特率115200
//附带忙闲指示信号rdy
module uart_tx 
    #(
    parameter BAUDRATE = 115200,
    parameter FREQ = 200_000_000
    )
(
    
    input 			clk, 
    input 			_rst,
    input 			wrreq,
    input 	[7:0] 	wdata,
    
    output 	reg 	tx,
    output 	reg 	rdy
);
    reg 	[3:0] 	cnt_bit;
    reg 	[31:0] 	cnt_clk;

    localparam T = FREQ / BAUDRATE; //每位信号发送时间

//有写请求时将rdy信号拉低，待到数据发送完毕再将信号拉高
always @(posedge clk or negedge _rst) begin
	if(_rst == 0)
		rdy <= 1;
	else if(wrreq)
		rdy <= 0;
	else if(end_cnt_bit)
		rdy <= 1;
    else
        rdy <= 1;
end

//UART计数器
    wire end_cnt_clk;
    wire end_cnt_bit;
    assign end_cnt_clk = cnt_clk == T - 1;
    assign end_cnt_bit = end_cnt_clk && cnt_bit == 10 - 1;

	// 两层计数结构
	//8个数据位
    //一个停止位
    //共10位

//cnt_clk计数每一位所占的时钟数
always @(posedge clk or negedge _rst) begin
	if(_rst == 0)
		cnt_clk <= 0;
	else if(rdy == 0) begin
		if(end_cnt_clk)
			cnt_clk <= 0;
		else
        	cnt_clk <= cnt_clk + 1'b1;
	end
end

//cnt_bit计数1个开始位
always @(posedge clk or negedge _rst) begin
	if(_rst == 0)
		cnt_bit <= 0;
	else if(end_cnt_clk) begin
		if(end_cnt_bit)
			cnt_bit <= 0;
		else
			cnt_bit <= cnt_bit + 1'b1;
	end
end

//先发送一个起始位0，然后8位数据位，最后是停止位1
always @(posedge clk or negedge _rst) begin
	if(_rst == 0)
		tx <= 1;
	else if(rdy == 0 && cnt_clk == 0) begin
		if(cnt_bit == 1 - 1)
        	tx <= 0;
		else if(cnt_bit == 10 - 1)
			tx <= 1;
		else
			tx <= wdata[cnt_bit - 1];
	end
end

endmodule
```

### RX-UART

```verilog
`timescale 1ns/1ps

//系统时钟200MHz，波特率115200
module uart_rx  
    #(
    parameter BAUDRATE = 115200,
    parameter FREQ = 200_000_000
    )
(
    input 					clk,
    input					_rst,
    input 					rx,
    
    output 	reg 	[7:0] 	rdata,
    output 	reg 			vld
);

    localparam T = FREQ / BAUDRATE;
	reg flag; //接受处理标志位，为1表明当前处于接受状态
    
//接收状态控制
always @(posedge clk or negedge _rst) begin
	if(_rst == 0)
		flag <= 0;
	else if(flag == 0 && rx == 0)
		flag <= 1;
	else if(cnt_bit == 1 - 1 && cnt_clk == T / 2 - 1 && rx == 1)
		flag <= 0;
	else if(end_cnt_bit)
		flag <= 0;
end

	reg [3:0] cnt_bit;
    reg [31:0] cnt_clk;
    assign end_cnt_clk = cnt_clk == T - 1;
    assign end_cnt_bit = end_cnt_clk && cnt_bit == 10 - 1;

//cnt_clk计数每一位所占的时钟数
always @(posedge clk or negedge _rst) begin
	if(_rst == 0)
		cnt_clk <= 0;
	else if(flag) begin
		if(end_cnt_clk)
			cnt_clk <= 0;
		else
			cnt_clk <= cnt_clk + 1'b1;
	end
	else
		cnt_clk <= 0;
end

//cnt_bit计数1个开始位
always @(posedge clk or negedge _rst) begin
	if(_rst == 0)
		cnt_bit <= 0;
	else if(end_cnt_clk) begin
		if(end_cnt_bit)
			cnt_bit <= 0;
		else
			cnt_bit <= cnt_bit + 1'b1;
	end
end

//读数据及数据有效指示信号
always @(posedge clk or negedge _rst) begin
	if(_rst == 0)
		rdata <= 0;
	else if(cnt_clk == T / 2 - 1 && cnt_bit != 1 - 1 && cnt_bit != 10 - 1)
		rdata[cnt_bit - 1] <= rx;
end

always @(posedge clk or negedge _rst) begin
	if(_rst == 0)
    	vld <= 0;
	else if(end_cnt_bit)
		vld <= 1;
	else
		vld <= 0;
end

endmodule
```

### 一个可实际应用的UART设计

本设计摘录自蜂鸟E203的配套SoC，详细内容可参考蜂鸟E203官方文档

tx部分

```verilog
module uart_tx (
    input  wire        clk_i,
    input  wire        rstn_i,
    output reg         tx_o,
    output wire        busy_o,
    input  wire        cfg_en_i,
    input  wire [15:0] cfg_div_i,
    input  wire        cfg_parity_en_i,
    input  wire [1:0]  cfg_parity_sel_i,
    input  wire [1:0]  cfg_bits_i,
    input  wire        cfg_stop_bits_i,
    input  wire [7:0]  tx_data_i,
    input  wire        tx_valid_i,
    output reg         tx_ready_o
);

    localparam [2:0] IDLE           = 0;
    localparam [2:0] START_BIT      = 1;
    localparam [2:0] DATA           = 2;
    localparam [2:0] PARITY         = 3;
    localparam [2:0] STOP_BIT_FIRST = 4;
    localparam [2:0] STOP_BIT_LAST  = 5;

    reg [2:0]  CS,NS;
   
    reg [7:0]  reg_data;
    reg [7:0]  reg_data_next;
    reg [2:0]  reg_bit_count;
    reg [2:0]  reg_bit_count_next;

    reg [2:0]  s_target_bits;

    reg        parity_bit;
    reg        parity_bit_next;

    reg        sampleData;

    reg [15:0] baud_cnt;
    reg        baudgen_en;
    reg        bit_done;

    assign busy_o = (CS != IDLE);

    always @(*) begin
        case (cfg_bits_i)
            2'b00: s_target_bits = 3'h4;
            2'b01: s_target_bits = 3'h5;
            2'b10: s_target_bits = 3'h6;
            2'b11: s_target_bits = 3'h7;
        endcase
    end
    
    always @(*) begin
        NS                 = CS;
        tx_o               = 1'b1;
        sampleData         = 1'b0;
        reg_bit_count_next = reg_bit_count;
        reg_data_next      = {1'b1, reg_data[7:1]};
        tx_ready_o         = 1'b0;
        baudgen_en         = 1'b0;
        parity_bit_next    = parity_bit;

        case (CS)
            IDLE: begin
                if (cfg_en_i)
                    tx_ready_o = 1'b1;
                if (tx_valid_i) begin
                    NS            = START_BIT;
                    sampleData    = 1'b1;
                    reg_data_next = tx_data_i;
                end
            end
            START_BIT: begin
                tx_o            = 1'b0;
                parity_bit_next = 1'b0;
                baudgen_en      = 1'b1;
                if (bit_done)
                    NS = DATA;
            end
            DATA: begin
                tx_o            = reg_data[0];
                baudgen_en      = 1'b1;
                parity_bit_next = parity_bit ^ reg_data[0];

		if (bit_done) begin
                    if (reg_bit_count == s_target_bits) begin
                        reg_bit_count_next = 'h0;
                        if (cfg_parity_en_i)
                            NS = PARITY;
                        else
                            NS = STOP_BIT_FIRST;
		    end else begin
                        reg_bit_count_next = reg_bit_count + 1;
                        sampleData         = 1'b1;
                    end
		end
            end
            PARITY: begin
                case (cfg_parity_sel_i)
                    2'b00: tx_o = ~parity_bit;
                    2'b01: tx_o = parity_bit;
                    2'b10: tx_o = 1'b0;
                    2'b11: tx_o = 1'b1;
                endcase

                baudgen_en = 1'b1;

                if (bit_done)
                    NS = STOP_BIT_FIRST;
            end
            STOP_BIT_FIRST: begin
                tx_o       = 1'b1;
                baudgen_en = 1'b1;

		if (bit_done) begin
                    if (cfg_stop_bits_i)
                        NS = STOP_BIT_LAST;
                    else
                        NS = IDLE;
		end
            end
            STOP_BIT_LAST: begin
                tx_o = 1'b1;
                baudgen_en = 1'b1;
                if (bit_done)
                    NS = IDLE;
            end
            default: NS = IDLE;
        endcase
    end


    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            CS            <= IDLE;
            reg_data      <= 8'hff;
            reg_bit_count <= 'h0;
            parity_bit    <= 1'b0;
	end else begin
            if (bit_done)
                parity_bit <= parity_bit_next;
            if (sampleData)
                reg_data   <= reg_data_next;

            reg_bit_count  <= reg_bit_count_next;
            
	    if (cfg_en_i)
                CS <= NS;
            else
                CS <= IDLE;
        end
    end

    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            baud_cnt <= 'h0;
            bit_done <= 1'b0;
	end else if (baudgen_en) begin
            if (baud_cnt == cfg_div_i) begin
                baud_cnt <= 'h0;
                bit_done <= 1'b1;
            end
            else begin
                baud_cnt <= baud_cnt + 1;
                bit_done <= 1'b0;
            end
	end else begin
            baud_cnt <= 'h0;
            bit_done <= 1'b0;
        end
    end

    //synopsys translate_off
    always @(posedge clk_i or negedge rstn_i) begin
        if ((tx_valid_i & tx_ready_o) & rstn_i)
            $fwrite(32'h80000002, "%c", tx_data_i);
    end
    //synopsys translate_on    

endmodule
```

rx部分

```verilog
module uart_rx (
    input  wire        clk_i,
    input  wire        rstn_i,
    input  wire        rx_i,
    input  wire [15:0] cfg_div_i,
    input  wire        cfg_en_i,
    input  wire        cfg_parity_en_i,
    input  wire [1:0]  cfg_parity_sel_i,
    input  wire [1:0]  cfg_bits_i,
    // input  wire        cfg_stop_bits_i,
    output wire        busy_o,
    output reg         err_o,
    input  wire        err_clr_i,
    output wire [7:0]  rx_data_o,
    output reg         rx_valid_o,
    input  wire        rx_ready_i
);

    localparam [2:0] IDLE      = 0;
    localparam [2:0] START_BIT = 1;
    localparam [2:0] DATA      = 2;
    localparam [2:0] SAVE_DATA = 3;
    localparam [2:0] PARITY    = 4;
    localparam [2:0] STOP_BIT  = 5;

    reg [2:0]  CS, NS;

    reg [7:0]  reg_data;
    reg [7:0]  reg_data_next;
    reg [2:0]  reg_rx_sync;
    reg [2:0]  reg_bit_count;
    reg [2:0]  reg_bit_count_next;

    reg [2:0]  s_target_bits;

    reg        parity_bit;
    reg        parity_bit_next;

    reg        sampleData;

    reg [15:0] baud_cnt;
    reg        baudgen_en;
    reg        bit_done;

    reg        start_bit;
    reg        set_error;
    wire       s_rx_fall;

    assign busy_o = (CS != IDLE);

    always @(*) begin
        case (cfg_bits_i)
            2'b00: s_target_bits = 3'h4;
            2'b01: s_target_bits = 3'h5;
            2'b10: s_target_bits = 3'h6;
            2'b11: s_target_bits = 3'h7;
        endcase
    end


    always @(*) begin
        NS = CS;
        sampleData = 1'b0;
        reg_bit_count_next = reg_bit_count;
        reg_data_next = reg_data;
        rx_valid_o = 1'b0;
        baudgen_en = 1'b0;
        start_bit = 1'b0;
        parity_bit_next = parity_bit;
        set_error = 1'b0;

        case (CS)
	    IDLE: begin
                if (s_rx_fall) begin
                    NS         = START_BIT;
                    baudgen_en = 1'b1;
                    start_bit  = 1'b1;
                end
	    end
            START_BIT: begin
                parity_bit_next = 1'b0;
                baudgen_en      = 1'b1;
                start_bit       = 1'b1;
                if (bit_done) NS = DATA;
            end
            DATA: begin
                baudgen_en      = 1'b1;
                parity_bit_next = parity_bit ^ reg_rx_sync[2];

                case (cfg_bits_i)
                    2'b00: reg_data_next = {3'b0, reg_rx_sync[2], reg_data[4:1]};
                    2'b01: reg_data_next = {2'b0, reg_rx_sync[2], reg_data[5:1]};
                    2'b10: reg_data_next = {1'b0, reg_rx_sync[2], reg_data[6:1]};
                    2'b11: reg_data_next = {reg_rx_sync[2], reg_data[7:1]};
                endcase

                if (bit_done) begin
                    sampleData = 1'b1;
                    if (reg_bit_count == s_target_bits) begin
                    	reg_bit_count_next = 'h0;
                    	NS = SAVE_DATA;
	            end else begin
                    	reg_bit_count_next = reg_bit_count + 1;
		    end
                end
            end
            SAVE_DATA: begin
                baudgen_en = 1'b1;
                rx_valid_o = 1'b1;
		if (rx_ready_i) begin
                    if (cfg_parity_en_i) NS = PARITY;
                    else NS = STOP_BIT;
	        end
            end
            PARITY: begin
                baudgen_en = 1'b1;
                if (bit_done) begin
                    case (cfg_parity_sel_i)
                        2'b00:
                            if (reg_rx_sync[2] != ~parity_bit) set_error = 1'b1;
                        2'b01:
                            if (reg_rx_sync[2] != parity_bit) set_error = 1'b1;
                        2'b10:
                            if (reg_rx_sync[2] != 1'b0) set_error = 1'b1;
                        2'b11:
                            if (reg_rx_sync[2] != 1'b1) set_error = 1'b1;
                    endcase
                    NS = STOP_BIT;
                end
            end
            STOP_BIT: begin
                baudgen_en = 1'b1;
                if (bit_done) NS = IDLE;
            end
            default: NS = IDLE;
        endcase
    end


    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            CS            <= IDLE;
            reg_data      <= 8'hff;
            reg_bit_count <= 'h0;
            parity_bit    <= 1'b0;
	end else begin
            if (bit_done)
                parity_bit <= parity_bit_next;
            if (sampleData)
                reg_data <= reg_data_next;

            reg_bit_count <= reg_bit_count_next;

            if (cfg_en_i)
                CS <= NS;
            else
                CS <= IDLE;
        end
    end

    assign s_rx_fall = ~reg_rx_sync[1] & reg_rx_sync[2];

    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0)
            reg_rx_sync <= 3'b111;
        else if (cfg_en_i)
            reg_rx_sync <= {reg_rx_sync[1:0], rx_i};
        else
            reg_rx_sync <= 3'b111;
    end

    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            baud_cnt <= 'h0;
            bit_done <= 1'b0;
	end else if (baudgen_en) begin
            if (!start_bit && (baud_cnt == cfg_div_i)) begin
                baud_cnt <= 'h0;
                bit_done <= 1'b1;
	    end else if (start_bit && (baud_cnt == {1'b0, cfg_div_i[15:1]})) begin
                baud_cnt <= 'h0;
                bit_done <= 1'b1;
	    end else begin
                baud_cnt <= baud_cnt + 1;
                bit_done <= 1'b0;
            end
	end else begin
            baud_cnt <= 'h0;
            bit_done <= 1'b0;
        end
    end


    always @(posedge clk_i or negedge rstn_i)
        if (rstn_i == 1'b0)
            err_o <= 1'b0;
        else if (err_clr_i)
       	    err_o <= 1'b0;
        else if (set_error)
       	    err_o <= 1'b1;

    assign rx_data_o = reg_data;

endmodule
```

FIIO部分

```verilog
module io_generic_fifo 
#(
    parameter DATA_WIDTH = 32,
    parameter BUFFER_DEPTH = 2,
    parameter LOG_BUFFER_DEPTH = $clog2(BUFFER_DEPTH)
)
(
    input  wire                      clk_i,
    input  wire                      rstn_i,
    input  wire                      clr_i,
    output wire [LOG_BUFFER_DEPTH:0] elements_o,
    output wire [DATA_WIDTH - 1:0]   data_o,
    output wire                      valid_o,
    input  wire                      ready_i,
    input  wire                      valid_i,
    input  wire [DATA_WIDTH - 1:0]   data_i,
    output wire                      ready_o
);
    // Internal data structures
    reg [LOG_BUFFER_DEPTH - 1:0] pointer_in;      // location to which we last wrote
    reg [LOG_BUFFER_DEPTH - 1:0] pointer_out;     // location from which we last sent

    reg [LOG_BUFFER_DEPTH:0]     elements;        // number of elements in the buffer
    reg [DATA_WIDTH - 1:0]       buffer [BUFFER_DEPTH - 1:0];
    wire                         full;
   
   
    assign full       = (elements == BUFFER_DEPTH);
    assign elements_o = elements;

    always @(posedge clk_i or negedge rstn_i) begin : elements_sequential
        if (rstn_i == 1'b0)
            elements <= 0;
        else if (clr_i)
            elements <= 0;
        // ------------------
        // Are we filling up?
        // ------------------
        // One out, none in
        else if ((ready_i && valid_o) && (!valid_i || full))
            elements <= elements - 1;
        // None out, one in
        else if (((!valid_o || !ready_i) && valid_i) && !full)
            elements <= elements + 1;
        // Else, either one out and one in, or none out and none in - stays unchanged
    end

    integer loop1;
    always @(posedge clk_i or negedge rstn_i) begin : buffers_sequential
        if (rstn_i == 1'b0) begin
            for (loop1 = 0; loop1 < BUFFER_DEPTH; loop1 = loop1 + 1) begin
                buffer[loop1] <= 0;
            end
        end else if (valid_i && !full) begin
            buffer[pointer_in] <= data_i;     // Update the memory
        end
    end

    always @(posedge clk_i or negedge rstn_i) begin : sequential
        if (rstn_i == 1'b0) begin
            pointer_out <= 0;
            pointer_in  <= 0;
	end else if (clr_i) begin
            pointer_out <= 0;
            pointer_in  <= 0;
	end else begin

            // ------------------------------------
            // Check what to do with the input side
            // ------------------------------------
            // We have some input, increase by 1 the input pointer		
	    if (valid_i && !full) begin
                if (pointer_in == $unsigned(BUFFER_DEPTH - 1))
               	    pointer_in <= 0;
                else
               	    pointer_in <= pointer_in + 1;
            end
            // Else we don't have any input, the input pointer stays the same
            
	    
	    // -------------------------------------
            // Check what to do with the output side
            // -------------------------------------
            // We had pushed one flit out, we can try to go for the next one
	    if (ready_i && valid_o) begin
                if (pointer_out == $unsigned(BUFFER_DEPTH - 1))
                    pointer_out <= 0;
                else
                    pointer_out <= pointer_out + 1;
            end
            // Else stay on the same output location
        end
    end


    // Update output ports
    assign data_o  = buffer[pointer_out];
    assign valid_o = (elements != 0);
    assign ready_o = ~full;

endmodule
```

interrupt部分

```verilog
module uart_interrupt
#(
    parameter TX_FIFO_DEPTH = 32,
    parameter RX_FIFO_DEPTH = 32
)
(
    input  wire                           clk_i,
    input  wire                           rstn_i,

    // registers
    input  wire [2:0]                     IER_i,             // interrupt enable register

    // control logic
    input  wire                           error_i,
    input  wire [$clog2(RX_FIFO_DEPTH):0] rx_elements_i,
    input  wire [$clog2(TX_FIFO_DEPTH):0] tx_elements_i,
    input  wire [1:0]                     trigger_level_i,

    input  wire [3:0]                     clr_int_i,         // one hot

    output wire                           interrupt_o,
    output wire [3:0]                     IIR_o
);

    reg [3:0] iir_n;
    reg [3:0] iir_q;
    reg trigger_level_reached;

    always @(*) begin
        trigger_level_reached = 1'b0;
        case (trigger_level_i)
            2'b00:
                if ($unsigned(rx_elements_i) == 1)
            	    trigger_level_reached = 1'b1;
            2'b01:
                if ($unsigned(rx_elements_i) == 4)
            	    trigger_level_reached = 1'b1;
            2'b10:
                if ($unsigned(rx_elements_i) == 8)
            	    trigger_level_reached = 1'b1;
            2'b11:
                if ($unsigned(rx_elements_i) == 14)
            	    trigger_level_reached = 1'b1;
        endcase
    end


    always @(*) begin
        if (clr_int_i == 4'b0) begin
            // Receive data parity error
            if (IER_i[2] & error_i)
            	iir_n = 4'b1100;
            // Trigger level reached in FIFO mode
            else if (IER_i[0] & trigger_level_reached)
            	iir_n = 4'b1000;
            // Transmitter holding register empty
            else if (IER_i[1] & (tx_elements_i == 0))
            	iir_n = 4'b0100;
            else
            	iir_n = iir_q;
        end else begin
            iir_n = iir_q & ~clr_int_i;
        end
    end


    always @(posedge clk_i or negedge rstn_i) begin
        if (~rstn_i)
       	    iir_q <= 4'b0001;
        else
       	    iir_q <= iir_n;
    end

    assign IIR_o = iir_q;
    assign interrupt_o = ~iir_q[0];

endmodule
```

顶层模块

```verilog
module apb_uart_sv 
#(
    parameter APB_ADDR_WIDTH = 12  //APB slaves are 4KB by default
)
(
    input  wire                        CLK,
    input  wire                        RSTN,
    input  wire [APB_ADDR_WIDTH - 1:0] PADDR,
    input  wire [31:0]                 PWDATA,
    input  wire                        PWRITE,
    input  wire                        PSEL,
    input  wire                        PENABLE,
    output reg [31:0]                  PRDATA,
    output wire                        PREADY,
    output wire                        PSLVERR,
    input  wire                        rx_i,     // Receiver input
    output wire                        tx_o,     // Transmitter output
    output wire                        event_o   // interrupt/event output

);

    // register addresses
    parameter RBR = 3'h0, THR = 3'h0, DLL = 3'h0, IER = 3'h1, DLM = 3'h1, IIR = 3'h2,
              FCR = 3'h2, LCR = 3'h3, MCR = 3'h4, LSR = 3'h5, MSR = 3'h6, SCR = 3'h7;

    parameter TX_FIFO_DEPTH = 16; // in bytes
    parameter RX_FIFO_DEPTH = 16; // in bytes


    wire [2:0]  register_adr;
    reg  [79:0] regs_q, regs_n;
    reg  [1:0]  trigger_level_n, trigger_level_q;


    // receive buffer register, read only
    wire [7:0]  rx_data;
    // parity error
    wire        parity_error;
    wire [3:0]  IIR_o;
    reg  [3:0]  clr_int;
    // tx flow control
    wire        tx_ready;
    // rx flow control
    reg         apb_rx_ready;
    wire        rx_valid;

    reg         tx_fifo_clr_n, tx_fifo_clr_q;
    reg         rx_fifo_clr_n, rx_fifo_clr_q;

    reg         fifo_tx_valid;
    wire        tx_valid;
    wire        fifo_rx_valid;
    reg         fifo_rx_ready;
    wire        rx_ready;

    reg  [7:0]  fifo_tx_data;
    wire [8:0]  fifo_rx_data;
    wire [7:0]  tx_data;

    wire [$clog2(TX_FIFO_DEPTH):0] tx_elements;
    wire [$clog2(RX_FIFO_DEPTH):0] rx_elements;

    // TODO: check that stop bits are really not necessary here
    uart_rx uart_rx_i(
        .clk_i            ( CLK                                                      ),
        .rstn_i           ( RSTN                                                     ),
        .rx_i             ( rx_i                                                     ),
        .cfg_en_i         ( 1'b1                                                     ),
        .cfg_div_i        ( {regs_q[(DLM + 'd8) * 8+:8], regs_q[(DLL + 'd8) * 8+:8]} ),
        .cfg_parity_en_i  ( regs_q[(LCR * 8) + 3]                                    ),
        .cfg_parity_sel_i ( regs_q[(LCR * 8) + 5-:2]                                 ),
        .cfg_bits_i       ( regs_q[(LCR * 8) + 1-:2]                                 ),
        // .cfg_stop_bits_i    ( regs_q[(LCR * 8) + 2]                               ),
        .busy_o           (                                                          ),
        .err_o            ( parity_error                                             ),
        .err_clr_i        ( 1'b0                                                     ),
        .rx_data_o        ( rx_data                                                  ),
        .rx_valid_o       ( rx_valid                                                 ),
        .rx_ready_i       ( rx_ready                                                 )
    );

    uart_tx uart_tx_i(
        .clk_i            ( CLK                                                      ),
        .rstn_i           ( RSTN                                                     ),
        .tx_o             ( tx_o                                                     ),
        .busy_o           (                                                          ),
        .cfg_en_i         ( 1'b1                                                     ),
        .cfg_div_i        ( {regs_q[(DLM + 'd8) * 8+:8], regs_q[(DLL + 'd8) * 8+:8]} ),
        .cfg_parity_en_i  ( regs_q[(LCR * 8) + 3]                                    ),
        .cfg_parity_sel_i ( regs_q[(LCR * 8) + 5-:2]                                 ),
        .cfg_bits_i       ( regs_q[(LCR * 8) + 1-:2]                                 ),
        .cfg_stop_bits_i  ( regs_q[(LCR * 8) + 2]                                    ),
        .tx_data_i        ( tx_data                                                  ),
        .tx_valid_i       ( tx_valid                                                 ),
        .tx_ready_o       ( tx_ready                                                 )
    );

    io_generic_fifo #(
        .DATA_WIDTH       (9),
        .BUFFER_DEPTH     (RX_FIFO_DEPTH)
    ) uart_rx_fifo_i(
        .clk_i            ( CLK                                    ),
        .rstn_i           ( RSTN                                   ),
        .clr_i            ( rx_fifo_clr_q                          ),
        .elements_o       ( rx_elements                            ),
        .data_o           ( fifo_rx_data                           ),
        .valid_o          ( fifo_rx_valid                          ),
        .ready_i          ( fifo_rx_ready                          ),
        .valid_i          ( rx_valid                               ),
        .data_i           ( {parity_error, rx_data}                ),
        .ready_o          ( rx_ready                               )
    );

    io_generic_fifo #(
        .DATA_WIDTH       (8),
        .BUFFER_DEPTH     (TX_FIFO_DEPTH)
    ) uart_tx_fifo_i(
        .clk_i            ( CLK                                    ),
        .rstn_i           ( RSTN                                   ),
        .clr_i            ( tx_fifo_clr_q                          ),
        .elements_o       ( tx_elements                            ),
        .data_o           ( tx_data                                ),
        .valid_o          ( tx_valid                               ),
        .ready_i          ( tx_ready                               ),
        .valid_i          ( fifo_tx_valid                          ),
        .data_i           ( fifo_tx_data                           ),
        // not needed since we are getting the status via the fifo population
        .ready_o          (                                        )
    );

    uart_interrupt #(
        .TX_FIFO_DEPTH    (TX_FIFO_DEPTH),
        .RX_FIFO_DEPTH    (RX_FIFO_DEPTH)
    ) uart_interrupt_i(
        .clk_i            ( CLK                                    ),
        .rstn_i           ( RSTN                                   ),
        .IER_i            ( regs_q[(IER * 8) + 2-:3]               ),    // interrupt enable register
        .error_i          ( regs_n[(LSR * 8) + 2]                  ),
        .rx_elements_i    ( rx_elements                            ),
        .tx_elements_i    ( tx_elements                            ),
        .trigger_level_i  ( trigger_level_q                        ),
        .clr_int_i        ( clr_int                                ),    // one hot
        .interrupt_o      ( event_o                                ),
        .IIR_o            ( IIR_o                                  )
    );

    // UART Registers
    // register write and update logic
    always @(*) begin
        regs_n          = regs_q;
        trigger_level_n = trigger_level_q;

        fifo_tx_valid   = 1'b0;        
        tx_fifo_clr_n   = 1'b0; // self clearing
        rx_fifo_clr_n   = 1'b0; // self clearing

        // rx status
        regs_n[LSR * 8] = fifo_rx_valid; // fifo is empty

        // parity error on receiving part has occured
        regs_n[(LSR * 8) + 2] = fifo_rx_data[8];            // parity error is detected when element is retrieved

        // tx status register
        regs_n[(LSR * 8) + 5] = ~(|tx_elements);            // fifo is empty
        regs_n[(LSR * 8) + 6] = tx_ready & ~(|tx_elements); // shift register and fifo are empty

        if (PSEL && PENABLE && PWRITE)
        begin
            case (register_adr)
                THR: // either THR or DLL
                begin
		    if (regs_q[(LCR * 8) + 7]) begin // Divisor Latch Access Bit (DLAB)
                        regs_n[(DLL + 'd8) * 8+:8] = PWDATA[7:0];
		    end else begin
                        fifo_tx_data  = PWDATA[7:0];
                        fifo_tx_valid = 1'b1;
                    end
                end

                IER: // either IER or DLM
                begin
                    if (regs_q[(LCR * 8) + 7]) // Divisor Latch Access Bit (DLAB)
                        regs_n[(DLM + 'd8) * 8+:8] = PWDATA[7:0];
                    else
                        regs_n[IER * 8+:8] = PWDATA[7:0];
                end

                LCR:
                    regs_n[LCR * 8+:8] = PWDATA[7:0];

                FCR: // write only register, fifo control register
                begin
                    rx_fifo_clr_n   = PWDATA[1];
                    tx_fifo_clr_n   = PWDATA[2];
                    trigger_level_n = PWDATA[7:6];
                end
            endcase
        end

    end


    // register read logic
    always @(*) begin
        PRDATA        = 'b0;
        apb_rx_ready  = 1'b0;
        fifo_rx_ready = 1'b0;
        clr_int       = 4'b0;

        if (PSEL && PENABLE && !PWRITE)
        begin
            case (register_adr)
                RBR: // either RBR or DLL
                begin
                    if (regs_q[(LCR * 8) + 7]) // Divisor Latch Access Bit (DLAB)
                        PRDATA = {24'b0, regs_q[(DLL + 'd8) * 8+:8]};
		    else begin
                        fifo_rx_ready = 1'b1;
                        PRDATA        = {24'b0, fifo_rx_data[7:0]};
                        clr_int       = 4'b1000; // clear Received Data Available interrupt
                    end
                end

                LSR: // Line Status Register
                begin
                    PRDATA  = {24'b0, regs_q[LSR * 8+:8]};
                    clr_int = 4'b1100; // clear parrity interrupt error
                end

                LCR: // Line Control Register
                    PRDATA = {24'b0, regs_q[LCR * 8+:8]};

                IER: // either IER or DLM
                begin
                    if (regs_q[(LCR * 8) + 7]) // Divisor Latch Access Bit (DLAB)
                        PRDATA = {24'b0, regs_q[(DLM + 'd8) * 8+:8]};
                    else
                        PRDATA = {24'b0, regs_q[IER * 8+:8]};
                end

                IIR: // interrupt identification register read only
                begin
                    PRDATA  = {24'b0, 1'b1, 1'b1, 2'b0, IIR_o};
                    clr_int = 4'b0100; // clear Transmitter Holding Register Empty
                end

                default: 
                    PRDATA = 'b0;
            endcase
        end
    end


    // synchronouse part
    always @(posedge CLK or negedge RSTN) begin
	if(~RSTN) begin

            regs_q[IER * 8+:8] <= 8'h00;
            regs_q[IIR * 8+:8] <= 8'h01;
            regs_q[LCR * 8+:8] <= 8'h00;
            regs_q[MCR * 8+:8] <= 8'h00;
            regs_q[LSR * 8+:8] <= 8'h60;
            regs_q[MSR * 8+:8] <= 8'h00;
            regs_q[SCR * 8+:8] <= 8'h00;
            regs_q[(DLM + 'd8) * 8+:8] <= 8'h00;
            regs_q[(DLL + 'd8) * 8+:8] <= 8'h00;

            trigger_level_q   <= 2'b00;
            tx_fifo_clr_q     <= 1'b0;
            rx_fifo_clr_q     <= 1'b0;

        end else begin
            regs_q          <= regs_n;
            trigger_level_q <= trigger_level_n;
            tx_fifo_clr_q   <= tx_fifo_clr_n;
            rx_fifo_clr_q   <= rx_fifo_clr_n;
        end
    end	  


    assign register_adr = {PADDR[4:2]};
    // APB logic: we are always ready to capture the data into our regs
    // not supporting transfare failure
    assign PREADY       = 1'b1;
    assign PSLVERR      = 1'b0;

endmodule
```

