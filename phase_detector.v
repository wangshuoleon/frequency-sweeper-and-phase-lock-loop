module phase_detector (
    input wire clk,            // 50 MHz clock
    input wire reset,          // Active-high reset
    input wire trigger,        // Rising edge triggers output and reset
    input wire [7:0] signal,  // Input signal to measure
    input wire [7:0] ref_sig, // Reference signal (8MHz)
    input wire [7:0] ref_sig_q, // Quadrature reference
    output reg signed [15:0] phase_out, // Phase in 0.01 degrees
    output reg [15:0] magnitude_out,    // output magnitute signal
    output reg data_valid    // Valid flag
);



// State encoding (binary)
parameter [1:0] 
    IDLE       = 2'b00,
    ACCUMULATE = 2'b01,
    HOLD       = 2'b10;

reg [1:0] state;      // Current state

// Product registers
reg signed [23:0] i_product, q_product;
reg signed [31:0] i_accum, q_accum;
reg trigger_delay;

// Detect rising edge of trigger
wire trigger_rise;
assign trigger_rise = trigger & ~trigger_delay;

// State transition logic
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        i_accum <= 0;
        q_accum <= 0;
        phase_out <= 0;
        magnitude_out <= 0;
        data_valid <= 0;
        trigger_delay <= 0;
    end else begin
        trigger_delay <= trigger;
        
        case (state)
            IDLE: begin
                data_valid <= 0;
                if (trigger_rise) begin
                    i_accum <= 0;
                    q_accum <= 0;
                    state <= ACCUMULATE;
                end
            end
            
            ACCUMULATE: begin
                // Multiply and accumulate
                i_product <= $signed(signal) * $signed(ref_sig);
                q_product <= $signed(signal) * $signed(ref_sig_q);
                
                i_accum <= i_accum + i_product;
                q_accum <= q_accum + q_product;
                
                if (trigger_rise) begin
                    state <= HOLD;
                end
            end
            
            HOLD: begin
                // Calculate phase (arctan(Q/I))
                if (i_accum == 0) begin
                    phase_out <= (q_accum > 0) ? 16'sd9000 : -16'sd9000;
                end else begin
                    phase_out <= (q_accum * 1000) / i_accum;
                end
                
                // Calculate magnitude (sqrt(I^2 + Q^2))
                magnitude_out <= (i_accum[31] ? -i_accum : i_accum) + 
                                 (q_accum[31] ? -q_accum : q_accum); // Approximation
                
                data_valid <= 1;
                state <= IDLE;
            end
        endcase
    end
end

endmodule

