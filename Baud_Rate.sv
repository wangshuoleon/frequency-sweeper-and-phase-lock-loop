//--------------------------------------------------------------
// 程序描述:
//     波特率发生器
// 作    者: 凌智电子
// 开始日期: 2018-08-24
// 完成日期: 2018-08-24
// 修改日期:
// 版    本: V1.0: 
// 调试工具: 
// 说    明:将50MHz时钟分成115200波特率
//     
//--------------------------------------------------------------
module Baud_Rate #(
parameter BAUD = 115200
)(
	input wire clk_50m,		//时钟
	output wire rxclk_en,	//波特率
	output wire txclk_en
);


parameter RX_ACC_MAX = 50000000 / (BAUD * 16);
parameter TX_ACC_MAX = 50000000 / (BAUD * 16) *16;
parameter RX_ACC_WIDTH = $clog2(RX_ACC_MAX);
parameter TX_ACC_WIDTH = $clog2(TX_ACC_MAX);
reg [RX_ACC_WIDTH - 1:0] rx_acc = 1;
reg [TX_ACC_WIDTH - 1:0] tx_acc = 1;

assign rxclk_en = (rx_acc == 5'd1);
assign txclk_en = (tx_acc == 9'd1);

always @(posedge clk_50m) 
begin
	if(rx_acc == RX_ACC_MAX[RX_ACC_WIDTH - 1:0])
		rx_acc <= 0;
	else
		rx_acc <= rx_acc + 5'b1;
end

always @(posedge clk_50m) 
begin
	if(tx_acc == TX_ACC_MAX[TX_ACC_WIDTH - 1:0])
		tx_acc <= 0;
	else
		tx_acc <= tx_acc + 9'b1;
end

endmodule 