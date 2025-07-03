module UART_TX_FIFO #(
    parameter UART_BAUD = 115200,
    parameter FIFO_WIDTH = 8,
    parameter FIFO_DEPTH = 16
) (
    input wire clk_50m,
    input wire reset,
    output wire tx,
    input wire [FIFO_WIDTH-1:0] fifo_data_in,
    input wire fifo_wr_en,
    output wire fifo_empty,
    output wire fifo_full,
    output wire fifo_almost_full
);

    // Internal signals
    wire uart_busy;
    reg uart_start;
    wire [7:0] uart_data;
    wire baud_clken;
    
    // FIFO read control signals
    reg fifo_rd_en;
    reg [1:0] state;
    
    // State definitions
    localparam IDLE = 2'b00;
    localparam WAIT_FOR_UART = 2'b01;
    localparam SEND_DATA = 2'b10;
    
    // UART Transmitter instance
    UART_TX uart_tx_inst (
        .tx(tx),
        .busy(uart_busy),
        .start(uart_start),
        .clk_50m(clk_50m),
        .clken(baud_clken),
        .data(uart_data)
    );
    
    // Baud Rate Generator instance
    Baud_Rate #(
        .BAUD(UART_BAUD)
    ) baud_gen_inst (
        .clk_50m(clk_50m),
        .rxclk_en(),  // Not used
        .txclk_en(baud_clken)
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
        .din(fifo_data_in),
        .full(fifo_full),
        .almost_full(fifo_almost_full),
        // Read interface
        .rd_en(fifo_rd_en),
        .dout(uart_data),
        .empty(fifo_empty),
        .almost_empty()  // Not used
    );
    
    // Control logic for FIFO-to-UART transmission
    always @(posedge clk_50m or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            fifo_rd_en <= 0;
            uart_start <= 0;
        end else begin
            // Default values
            fifo_rd_en <= 0;
            uart_start <= 0;
            
            case (state)
                IDLE: begin
                    if (!fifo_empty && !uart_busy) begin
                        fifo_rd_en <= 1;
                        state <= WAIT_FOR_UART;
                    end
                end
                
                WAIT_FOR_UART: begin
                    // Wait one cycle for FIFO data to be valid
                    state <= SEND_DATA;
                end
                
                SEND_DATA: begin
                    uart_start <= 1;
                    if (uart_busy) begin
                        // Wait until UART finishes transmission
                        uart_start <= 0;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule