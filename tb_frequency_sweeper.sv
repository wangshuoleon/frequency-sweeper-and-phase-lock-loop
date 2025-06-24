`timescale 1ns / 1ps

module tb_frequency_sweeper();

    // System clock and reset
    reg clk;
    reg reset;
    
    // FIFO Interface
    reg [79:0] fifo_data;
    reg fifo_empty;
    wire fifo_rd_en;
    
    // DDS Control Interface
    wire [31:0] dds_freq;
    wire sweep_start;
    wire sweep_done;
    
    // DDS Output
    wire [7:0] dac_data;
    wire [7:0] q_dac_data;
    wire phase_accumulator_reset;

    // phase detector
    reg [15:0] phase_out;
    reg [15:0] magnitude_out;
    wire data_valid;



    
    // Test parameters
    parameter CLK_PERIOD = 20;  // 50 MHz clock (20 ns period)
    
    // Sweep parameters - matches module's fixed 1024 steps
    parameter INIT_FREQ = 32'h0100_0000;    // Initial frequency tuning word
    parameter CYCLES_PER_STEP = 16'd1024;     // Clock cycles at each frequency (reduced for simulation)
    parameter FREQ_STEP = 32'h0001_0000;    // Frequency step size
    
    // Instruction format: {init_freq, cycles_per_step, freq_step}
    parameter SWEEP_INSTRUCTION = {INIT_FREQ, CYCLES_PER_STEP, FREQ_STEP};

    // Instantiate modules
    frequency_sweeper uut (
        .clk(clk),
        .reset(reset),
        .fifo_data(fifo_data),
        .fifo_empty(fifo_empty),
        .fifo_rd_en(fifo_rd_en),
        .dds_freq(dds_freq),
        .sweep_start(sweep_start),
        .sweep_done(sweep_done)
    );
    
    dds_sine_generator dds (
        .clk(clk),
        .reset(reset),
        .freq_tuning_word(dds_freq),
        .dac_data(dac_data),
        .q_dac_data(q_dac_data),
        .phase_accumulator_reset(phase_accumulator_reset)
    );

    phase_detector  pd(
        .clk(clk),            // 50 MHz clock
        .reset(reset),          // Active-high reset
        .trigger(phase_accumulator_reset),        // Rising edge triggers output and reset
        .signal(q_dac_data),  // Input signal to measure
        .ref_sig (dac_data), // Reference signal (8MHz)
        .ref_sig_q (q_dac_data), // Quadrature reference
        .phase_out (phase_out), // Phase in 0.01 degrees
        .magnitude_out (magnitude_out),    // output magnitute signal
        .data_valid(data_valid)    // Valid flag
    );
    

    // Clock generation
    always begin
        clk = 1'b0;
        #(CLK_PERIOD/2);
        clk = 1'b1;
        #(CLK_PERIOD/2);
    end
    
    // Test sequence
    initial begin
        // Initialize signals
        reset = 1'b1;
        fifo_empty = 1'b1;
        fifo_data = SWEEP_INSTRUCTION;
        
        // Reset the system
        #(CLK_PERIOD*2);
        reset = 1'b0;
        
        // Wait a bit
        #(CLK_PERIOD*5);
        
        // Load a sweep instruction
        
        fifo_empty = 1'b0;
        
        // Wait for the sweep to start
        wait(fifo_rd_en);
        fifo_empty = 1'b1;  // FIFO is now "empty"
        
        $display("============================================");
        $display("Sweep Parameters:");
        $display("Initial Frequency: %h", INIT_FREQ);
        $display("Cycles per Step: %d", CYCLES_PER_STEP);
        $display("Frequency Step: %h", FREQ_STEP);
        $display("Total Steps: 256 (fixed in module)");
        $display("============================================");
        $display("Sweep started at time %0t ns", $time);
        
        // Wait for sweep to complete
        wait(sweep_done);
        $display("Sweep completed at time %0t ns", $time);
        $display("Total sweep duration: %0t ns", $time - (CLK_PERIOD*8));
        
        // Verify final frequency
        #(CLK_PERIOD);
        $display("Final frequency tuning word: %h", dds_freq);
        $display("Expected final frequency: %h", INIT_FREQ + (FREQ_STEP * 1023));
        
        // End simulation
        #(CLK_PERIOD*10);
        $finish;
    end
    
    
    
    // VCD dump for waveform viewing
    initial begin
        $dumpfile("frequency_sweep.vcd");
        $dumpvars(0, tb_frequency_sweeper);
    end
    
endmodule