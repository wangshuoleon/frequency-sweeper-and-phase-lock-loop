module UART_RX_FIFO #(
    parameter UART_BAUD = 115200,
    parameter FIFO_WIDTH = 8,
    parameter FIFO_DEPTH = 16
) (
    input wire clk_50m,
    input wire reset,
    input wire rx,
    output wire [87:0] fifo_data_out,
    input wire fifo_rd_en,
    output wire fifo_empty,
    output wire fifo_full,
    output wire fifo_almost_full
);

    // Internal signals
    wire uart_rdy;
    reg uart_rdy_clr;
    wire [7:0] uart_data;
    wire baud_clken;
    
    // FIFO write control signals
    reg fifo_wr_en;
    reg [1:0] state;
    
    // State definitions
    localparam IDLE = 2'b00;
    localparam WAIT_FOR_FIFO = 2'b01;
    localparam WRITE_TO_FIFO = 2'b10;
    
    // UART Receiver instance
    UART_RX uart_rx_inst (
        .rx(rx),
        .rdy(uart_rdy),
        .rdy_clr(uart_rdy_clr),
        .clk_50m(clk_50m),
        .clken(baud_clken),
        .data(uart_data)
    );
    
    // Baud Rate Generator instance
    Baud_Rate #(
        .BAUD(UART_BAUD)
    ) baud_gen_inst (
        .clk_50m(clk_50m),
        .rxclk_en(baud_clken),
        .txclk_en()  // Not used
    );
    
    // FIFO instance
    fifo #(
        .WIDTH(FIFO_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) fifo_inst (
        .clk(clk_50m),
        .reset(reset),
        // Write interface
        .wr_en(fifo_wr_en),
        .din(uart_data),
        .full(fifo_full),
        .almost_full(fifo_almost_full),
        // Read interface
        .rd_en(fifo_rd_en),
        .dout(fifo_data_out),
        .empty(fifo_empty),
        .almost_empty()  // Not used
    );
    
    // Improved handshake control logic
    always @(posedge clk_50m or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            fifo_wr_en <= 0;
            uart_rdy_clr <= 0;
        end else begin
            // Default values
            fifo_wr_en <= 0;
            uart_rdy_clr <= 0;
            
            case (state)
                IDLE: begin
                    if (uart_rdy) begin
                        state <= WAIT_FOR_FIFO;
                    end
                end
                
                WAIT_FOR_FIFO: begin
                    if (!fifo_full) begin
                        state <= WRITE_TO_FIFO;
                        fifo_wr_en <= 1;
                        uart_rdy_clr <= 1;
                    end
                end
                
                WRITE_TO_FIFO: begin
                    // Clear the write enable after one cycle
                    fifo_wr_en <= 0;
                    uart_rdy_clr <= 0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule