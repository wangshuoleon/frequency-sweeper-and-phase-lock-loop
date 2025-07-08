`timescale 1ns / 1ps

module UART_FIFO_SWEEPER_TB;

    // Testbench Parameters
    parameter CLK_PERIOD = 20;      // 50MHz clock (20ns period)
    parameter BAUD_RATE = 115200;
    parameter BIT_PERIOD = 1000000000/BAUD_RATE; // 8.68us for 115200 baud
    
    // Module Inputs
    reg clk_50m;
    reg reset;
    reg rx;
    
    // UART-FIFO Outputs
    wire [87:0] fifo_data_out;
    wire fifo_empty;
    wire fifo_full;
    
    // Frequency Sweeper Connections
    wire [79:0] sweeper_fifo_data = {32'h0000FFFF, 16'd100, 32'h000000FF}; // Example instruction
    wire sweeper_fifo_rd_en;
    wire [31:0] dds_freq;
    wire sweep_start;
    wire sweep_done;
    wire frequency_update; // Pulse when new frequency is valid

    //dds
    reg [7:0] dac_data;
    reg [7:0] q_dac_data;
    reg  phase_accumulator_reset;

    // Phase Detector Outputs
    wire [39:0] q_component; // Phase in 0.01 degrees   
    wire [39:0] i_component; // Output magnitude signal
    wire data_valid;
    
    // uart_tx
    wire tx;
    wire output_fifo_empty;
    wire [7:0] fifo_output;
    wire read_fifo_flag; // FIFO read flag
    wire baud_clk; // Baud rate clock 


    // Instantiate the UART RX + FIFO module
    UART_RX_FIFO #(
        .UART_BAUD(BAUD_RATE),
        .FIFO_WIDTH(8),
        .FIFO_DEPTH(11)  // Larger FIFO for sweeper commands
    ) uart_fifo (
        .clk_50m(clk_50m),
        .reset(reset),
        .rx(rx),
        .fifo_data_out(fifo_data_out),
        .fifo_rd_en(sweeper_fifo_rd_en),
        .fifo_empty(fifo_empty),
        .fifo_full(fifo_full),
        .fifo_almost_full()  // Not used
    );
    
    // Instantiate the Frequency Sweeper
    frequency_sweeper sweeper (
        .clk(clk_50m),
        .reset(reset),
        .fifo_data({fifo_data_out}), // Adapt 8-bit FIFO to sweeper interface
        .fifo_empty(fifo_full),
        .fifo_rd_en(sweeper_fifo_rd_en),
        .dds_freq(dds_freq),
        .sweep_start(sweep_start),
        .sweep_done(sweep_done),
        .frequency_update(frequency_update), 
        .phase_error(16'h0),  // Not used in this test
        .pll_enable()     // Not used in this test
    );

    dds_sine_generator dds(
        .clk(clk_50m),
        .reset(reset),
        .freq_tuning_word(dds_freq), // Frequency control (32-bit precision)
        .dac_data (dac_data),     // 8-bit output to DAC
        .q_dac_data (q_dac_data),   // 8-bit output that Quadrature to the dac_data
        .phase_accumulator_reset (phase_accumulator_reset) 
    );

    // DDS Output to phase detector
    phase_detector  pd(
        .clk(clk_50m),            // 50 MHz clock
        .reset(reset),          // Active-high reset
        .trigger(frequency_update),        // Rising edge triggers output and reset
        .signal(dac_data),  // Input signal to measure
        .ref_sig(dac_data), // Reference signal (8MHz)
        .ref_sig_q(q_dac_data), // Quadrature reference
        .q_component(q_component), // Phase in 0.01 degrees
        .i_component(i_component),    // output magnitute signal
        .data_valid(data_valid)    // Valid flag
);


    
      // phase_detecter interface with output fifo
    fifo_80_to_8  fifo_output_module(
    .clk(clk_50m),
    .reset(reset),
    // 80-bit input interface
    .wr_en(data_valid),
    .din({ q_component, i_component }), // Concatenate Q and I components
    .full(),
    // 8-bit output interface
    .rd_en(read_fifo_flag), // Read signal from UART_TX
    .dout(fifo_output),
    .empty(output_fifo_empty), // FIFO empty flag
    .bytes_available()  // Count of available bytes
);

      // interface between fifo and uart_tx
    UART_TX send_to_host(
	.din(fifo_output),	//传输数据
	.wr_en(~output_fifo_empty),			//传输使能
	.clk_50m(clk_50m),		//时钟
	.clken(baud_clk),			//波特率
	.tx(tx),				//数据发送线
	.tx_busy(),		//传输忙
	.read_fifo_flag(read_fifo_flag) // FIFO read flag
);

    Baud_Rate #(
    .BAUD (BAUD_RATE)
) br (
	.clk_50m(clk_50m),		//时钟
	.rxclk_en(),	//波特率
	.txclk_en(baud_clk)
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
        
        // Reset the system
        #100;
        reset = 0;
        #100;
        
        // Test Case 1: Send frequency sweep command
        $display("=== Sending Sweep Command ===");
        // Send command bytes (LSB first)
        send_byte(8'hFF);  // freq_step[7:0]
        send_byte(8'h00);  // freq_step[15:8]
        send_byte(8'h00);  // freq_step[23:16]
        send_byte(8'h00);  // freq_step[31:24]
        send_byte(8'h64);  // cycles_per_step[7:0] (100)
        send_byte(8'h00);  // cycles_per_step[15:8]
        send_byte(8'hFF);  // init_freq[7:0]
        send_byte(8'hFF);  // init_freq[15:8]
        send_byte(8'h00);  // init_freq[23:16]
        send_byte(8'h00);  // init_freq[31:24]
        send_byte(8'h00);  // Mode select (0=sweep)
        
        // Wait for sweep to complete
        wait(sweep_done);
        $display("=== Sweep Complete ===");
        #10000;
        
        // Test Case 2: Send PLL command
        $display("=== Sending PLL Command ===");
        send_byte(8'h00);  // freq_step (unused)
        send_byte(8'h00);
        send_byte(8'h00);
        send_byte(8'h00);
        send_byte(8'h00);  // cycles_per_step (unused)
        send_byte(8'h00);
        send_byte(8'h80);  // init_freq[7:0] (center freq)
        send_byte(8'h00);  // init_freq[15:8]
        send_byte(8'h00);  // init_freq[23:16]
        send_byte(8'h00);  // init_freq[31:24]
        send_byte(8'h01);  // Mode select (1=PLL)
        
        #5000;
        $finish;
    end
    
    // Task to send a single byte
    task send_byte;
        input [7:0] byte_to_send;
        begin
            // Wait if FIFO is full
            //while(fifo_full) #(CLK_PERIOD*10);
            
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
        // Display FIFO writes
        if (uart_fifo.fifo_wr_en) begin
            $display("Time: %t, UART Received: 0x%h", $time, uart_fifo.uart_data);
        end
        
        // Display Sweeper activity
        if (sweep_start) begin
            $display("Time: %t, Sweep Started", $time);
        end
        
        if (sweeper_fifo_rd_en) begin
            $display("Time: %t, Sweeper Read FIFO", $time);
        end
        
        // Display frequency updates
        if (sweeper.state == sweeper.SWEEP && sweeper.cycle_counter == 0) begin
            $display("Time: %t, Frequency Updated: 0x%h", $time, dds_freq);
        end
    end
    
    // Create VCD file for waveform viewing
    initial begin
        $dumpfile("uart_fifo_sweeper_tb.vcd");
        $dumpvars(0, UART_FIFO_SWEEPER_TB);
    end
    
endmodule