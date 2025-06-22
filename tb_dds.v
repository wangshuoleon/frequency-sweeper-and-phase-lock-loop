`timescale 1ns/1ps
module tb_dds();

// Testbench signals
reg clk = 0;
reg reset = 1;
reg [31:0] freq_word = 32'h200_0000; // Tuning word for ~1.19MHz @ 50MHz clock
wire [7:0] dac_out;

// Instantiate DUT
dds_sine_generator dut (
    .clk(clk),
    .reset(reset),
    .freq_tuning_word(freq_word),
    .dac_data(dac_out)
);

// Clock generation (50MHz)
always #10 clk = ~clk; // 20ns period = 50MHz

// Initialize VCD dump
initial begin
    $dumpfile("dds_wave.vcd");
    $dumpvars(0, tb_dds); // Dump all signals
end

// Stimulus
initial begin
    #100 reset = 0; // Release reset after 100ns
    
    // Change frequency after 10us
    #10000 freq_word = 32'h400_0000; // Double frequency
    
    #20000 $finish; // Stop after 20us
end

endmodule