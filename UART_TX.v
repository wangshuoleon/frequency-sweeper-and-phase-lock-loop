//--------------------------------------------------------------
// 程序描述:
//     串口传输数据
// 作    者: 凌智电子
// 开始日期: 2018-08-24
// 完成日期: 2018-08-24
// 修改日期:
// 版    本: V1.0: 
// 调试工具: 
// 说    明:
//     
//--------------------------------------------------------------
module UART_TX(
	input wire [7:0] din,	//传输数据
	input wire wr_en,			//传输使能
	input wire clk_50m,		//时钟
	input wire clken,			//波特率
	output reg tx,				//数据发送线
	output wire tx_busy,		//传输忙
	output reg read_fifo_flag // FIFO read flag
);

initial begin
	 tx = 1'b1;	//数据发送线置位
end

localparam STATE_IDLE		= 3'b000;	//空闲状态
localparam STATE_START	    = 3'b001;	//开始
localparam STATE_DATA		= 3'b010;	//传输数据
localparam STATE_STOP		= 3'b011;	//停止
localparam STATE_LOAD		= 3'b100;	//加载状态
localparam STATE_WAIT		= 3'b101;	//等待状态


reg [7:0] data = 8'h00;			//传输数据寄存器
reg [2:0] bitpos = 3'h0;		//传输数据位位置
reg [2:0] state = STATE_IDLE;	//状态

always @(posedge clk_50m)
begin
	case(state)
		STATE_IDLE: //空闲状态
			 begin
        		if (wr_en) begin
            	bitpos <= 3'h0;
            	read_fifo_flag <= 1'b1; // Set flag for next cycle
				
            	state <= STATE_LOAD;   // Move to intermediate state
        		end
    		end

		STATE_LOAD:
    		begin
        		state <= STATE_WAIT; // Move to START state in the next cycle
				
                read_fifo_flag <= 1'b0; // Clear FIFO read flag
				
    		end


		STATE_WAIT: //等待状态
			// Wait for the next clock cycle to start transmission
			begin
				data<= din; // Capture din
				state <= STATE_START; // Move to START state in the next cycle
				
			end

		
		STATE_START: //开始
			begin					
				
				if(clken) 
					begin
						
						tx <= 1'b0;
						state <= STATE_DATA;
					end
			end
		STATE_DATA: //传输数据
			begin					
				if (clken) 
				begin
					if (bitpos == 3'h7)
						begin
							state <= STATE_STOP;
						end
					else
						begin
							bitpos <= bitpos + 3'h1;
						end
					tx <= data[bitpos];
				end
			end
		STATE_STOP: //结束
			begin
				if(clken) 
					begin
						tx <= 1'b1;
						state <= STATE_IDLE;
					end
			end
		default: 
			begin						
				tx <= 1'b1;
				state <= STATE_IDLE;
			end
	endcase
end

assign tx_busy = (state != STATE_IDLE);	//正在传输

endmodule 