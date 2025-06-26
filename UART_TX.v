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
	output wire tx_busy		//传输忙
);

initial begin
	 tx = 1'b1;	//数据发送线置位
end

parameter STATE_IDLE		= 2'b00;	//空闲状态
parameter STATE_START	= 2'b01;	//开始
parameter STATE_DATA		= 2'b10;	//传输数据
parameter STATE_STOP		= 2'b11;	//停止

reg [7:0] data = 8'h00;			//传输数据寄存器
reg [2:0] bitpos = 3'h0;		//传输数据位位置
reg [1:0] state = STATE_IDLE;	//状态

always @(posedge clk_50m)
begin
	case(state)
		STATE_IDLE: //空闲状态
			begin					
				if(wr_en) //判断是否可以传输
					begin				
						state <= STATE_START;
						data <= din;
						bitpos <= 3'h0;
					end
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