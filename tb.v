module tb_phase_detector();

reg clk = 0;
reg reset = 1;
reg [11:0] signal, ref_sig, ref_sig_q;
wire signed [15:0] phase_out;
wire phase_valid;

// Instantiate DUT
phase_detector dut (
    .clk(clk),
    .reset(reset),
    .signal(signal),
    .ref_sig(ref_sig),
    .ref_sig_q(ref_sig_q),
    .phase_out(phase_out),
    .phase_valid(phase_valid)
);

// Clock generation (50 MHz)
always #10 clk = ~clk;

// Reference signal generation (8MHz sine wave)
integer sample_count = 0;
always @(posedge clk) begin
    sample_count <= sample_count + 1;
    
    // Generate in-phase reference (simplified 8MHz sine)
    case (sample_count % 6)
        0: ref_sig <= 12'h000;
        1: ref_sig <= 12'h5A7;  // ~2047*sin(2π/6*1)
        2: ref_sig <= 12'hA57;  // ~2047*sin(2π/6*2)
        3: ref_sig <= 12'h000;
        4: ref_sig <= 12'hA58;  // Negative
        5: ref_sig <= 12'h5A8;  // Negative
    endcase
    
    // Generate quadrature reference (90° shifted)
    case (sample_count % 6)
        0: ref_sig_q <= 12'hA57;
        1: ref_sig_q <= 12'h5A7;
        2: ref_sig_q <= 12'h000;
        3: ref_sig_q <= 12'hA58;
        4: ref_sig_q <= 12'h5A8;
        5: ref_sig_q <= 12'h000;
    endcase
end

// Test sequence
initial begin
    // Reset
    #100 reset = 0;
    
    // Test 1: Same phase as reference
    $display("Testing 0° phase difference");
    repeat (1024) begin
        @(posedge clk);
        signal = ref_sig;
    end
    
    // Test 2: 90° phase difference
    $display("Testing 90° phase difference");
    repeat (1024) begin
        @(posedge clk);
        signal = ref_sig_q;
    end
    
    // Test 3: 45° phase difference
    $display("Testing 45° phase difference");
    repeat (1024) begin
        @(posedge clk);
        signal = (ref_sig + ref_sig_q) >>> 1; // Average = 45°
    end
    
    // Test 4: With some noise
    $display("Testing with noise");
    repeat (1024) begin
        @(posedge clk);
        signal = ref_sig + ($random % 100) - 50; // ±50 noise
    end
    
    $finish;
end

// Monitor results
always @(posedge phase_valid) begin
    $display("Phase detected: %0.2f degrees", phase_out / 100.0);
end

endmodule