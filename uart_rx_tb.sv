`timescale 1ns / 1ps

module UART_RX_FIFO_TB;

    // Testbench Parameters
    parameter CLK_PERIOD = 20;      // 50MHz clock (20ns period)
    parameter BAUD_RATE = 115200;
    parameter BIT_PERIOD = 1000000000/BAUD_RATE; // 8.68us for 115200 baud
    
    // Module Inputs
    reg clk_50m;
    reg reset;
    reg rx;
    reg fifo_rd_en;
    
    // Module Outputs
    wire [7:0] fifo_data_out;
    wire fifo_empty;
    wire fifo_full;
    wire fifo_almost_full;
    
    // Instantiate the UART RX + FIFO module
    UART_RX_FIFO #(
        .UART_BAUD(BAUD_RATE),
        .FIFO_WIDTH(8),
        .FIFO_DEPTH(4)  // Small FIFO for testing overflow
    ) uut (
        .clk_50m(clk_50m),
        .reset(reset),
        .rx(rx),
        .fifo_data_out(fifo_data_out),
        .fifo_rd_en(fifo_rd_en),
        .fifo_empty(fifo_empty),
        .fifo_full(fifo_full),
        .fifo_almost_full(fifo_almost_full)
    );
    
    // Clock Generation
    initial begin
        clk_50m = 0;
        forever #(CLK_PERIOD/2) clk_50m = ~clk_50m;
    end
    
    // Test Stimulus
    initial begin
        // Initialize Inputs
        rx = 1;       // Idle state is high
        reset = 1;
        fifo_rd_en = 0;
        
        // Reset the system
        #100;
        reset = 0;
        #100;
        
        // Test Case 1: Send three bytes (fill FIFO partially)
        send_byte(8'h55);
        send_byte(8'hAA);
        send_byte(8'h3C);
        #1000;
        
        // Read two bytes from FIFO
        fifo_rd_en = 1;
        #40;
        fifo_rd_en = 0;
        #100;
        fifo_rd_en = 1;
        #40;
        fifo_rd_en = 0;
        #500;
        
        // Test Case 2: Fill FIFO completely
        send_byte(8'h01);
        send_byte(8'h02);
        send_byte(8'h03);
        send_byte(8'h04);
        #1000;
        
        // Test Case 3: Attempt to write to full FIFO
        send_byte(8'hFF);  // This should be dropped
        #1000;
        
        // Read out all data
        fifo_rd_en = 1;
        #200;
        fifo_rd_en = 0;
        #500;
        
        // End simulation
        #1000;
        $finish;
    end
    
    // Task to send a single byte
    task send_byte;
        input [7:0] byte_to_send;
        begin
            // Start bit
            rx = 0;
            #(BIT_PERIOD);
            
            // Data bits (LSB first)
            for (integer i = 0; i < 8; i = i + 1) begin
                rx = byte_to_send[i];
                #(BIT_PERIOD);
            end
            
            // Stop bit
            rx = 1;
            #(BIT_PERIOD);
        end
    endtask
    
    // Monitor and display results
    always @(posedge clk_50m) begin
        if (fifo_rd_en && !fifo_empty) begin
            $display("Time: %t, Read from FIFO: 0x%h", $time, fifo_data_out);
        end
        if (uut.fifo_wr_en) begin
            $display("Time: %t, Wrote to FIFO: 0x%h", $time, uut.uart_data);
        end
        if (uut.uart_rdy && uut.fifo_full) begin
            $display("Time: %t, WARNING: FIFO full, data 0x%h dropped", $time, uut.uart_data);
        end
    end
    
    // Create VCD file for waveform viewing
    initial begin
        $dumpfile("uart_rx_fifo_tb.vcd");
        $dumpvars(0, UART_RX_FIFO_TB);
    end
    
endmodule