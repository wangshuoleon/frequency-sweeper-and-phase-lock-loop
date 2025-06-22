`define pi 3.14159265358979323846  // Define of  pi

module dds_sine_generator (
    input wire clk,               // System clock (e.g., 50 MHz)
    input wire reset,             // Active-high reset
    input wire [31:0] freq_tuning_word, // Frequency control (32-bit precision)
    output reg [7:0] dac_data     // 8-bit output to DAC
);

// Phase accumulator (32-bit for fine frequency resolution)
reg [31:0] phase_accumulator;

// ROM for 8-bit sine wave (256 entries, 8-bit output)
reg [7:0] sine_rom [0:255];

// Initialize ROM with sine values (precomputed)
initial begin
    integer i;
    for (i = 0; i < 256; i = i + 1) begin
        sine_rom[i] = 128 + $floor(127.0 * $sin(2.0 * `pi * i / 256.0));
    end
end

// Phase accumulation and ROM lookup
always @(posedge clk or posedge reset) begin
    if (reset) begin
        phase_accumulator <= 0;
        dac_data <= 0;
    end else begin
        // Update phase accumulator (wraps automatically)
        phase_accumulator <= phase_accumulator + freq_tuning_word;
        
        // Use top 8 bits of accumulator for ROM address
        dac_data <= sine_rom[phase_accumulator[31:24]];
    end
end

endmodule