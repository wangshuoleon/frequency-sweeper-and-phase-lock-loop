// Example top-level module
module top (
    input wire clk,
    input wire [31:0] freq_setting,
    output wire [7:0] dac_out
);

dds_sine_generator dds (
    .clk(clk),
    .reset(1'b0),
    .freq_tuning_word(freq_setting),
    .dac_data(dac_out)
);

endmodule