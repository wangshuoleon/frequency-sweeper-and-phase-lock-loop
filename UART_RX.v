//--------------------------------------------------------------
// 程序描述:
//     串口接收数据
// 作    者: 凌智电子
// 开始日期: 2018-08-24
// 完成日期: 2018-08-24
// 修改日期:
// 版    本: V1.0: 
// 调试工具: 
// 说    明:
//     
//--------------------------------------------------------------
module UART_RX(
	input wire rx,				//数据接收线
	output reg rdy,			//接收结束标志位
	input wire rdy_clr,		//接收结束标志位置零
	input wire clk_50m,		//时钟
	input wire clken,			//波特率
	output reg [7:0] data	//串口接收的数据
);

initial begin
	rdy = 0;
	data = 8'b0;
end

parameter RX_STATE_START	= 2'b00;	//开始
parameter RX_STATE_DATA		= 2'b01;	//接收数据
parameter RX_STATE_STOP		= 2'b10;	//停止

reg [1:0] state = RX_STATE_START;	//串口状态
reg [3:0] sample = 0;
reg [3:0] bitpos = 0;					//接收数据位位置
reg [7:0] scratch = 8'b0;

always @(posedge clk_50m) 
begin
	if(rdy_clr)
		rdy <= 0;

	if(clken) 
		begin
			case(state)
				RX_STATE_START: //从第一个低采样开始计数，一旦我们采集了一个完整的位就开始采集数据位
					begin
						if(!rx || sample != 0)
							sample <= sample + 4'b1;

						if(sample == 15) 
						begin
							state <= RX_STATE_DATA;
							bitpos <= 0;
							sample <= 0;
							scratch <= 0;
						end
					end
				RX_STATE_DATA: //开始采集数据位
					begin
						sample <= sample + 4'b1;
						if(sample == 4'h8) 
							begin
								scratch[bitpos[2:0]] <= rx;
								bitpos <= bitpos + 4'b1;
							end
						if (bitpos == 8 && sample == 15)
							state <= RX_STATE_STOP;
					end
				RX_STATE_STOP: //采集结束
					begin
						if (sample == 15 || (sample >= 8 && !rx)) 
							begin
								state <= RX_STATE_START;
								data <= scratch;
								rdy <= 1'b1;
								sample <= 0;
							end 
						else 
							begin
								sample <= sample + 4'b1;
							end
					end
				default: 
					begin
						state <= RX_STATE_START;
					end
		endcase
	end
end

endmodule 