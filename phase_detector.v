module phase_detector (
    input wire clk,            // 50 MHz clock
    input wire reset,          // Active-high reset
    input wire [11:0] signal,  // Input signal to measure
    input wire [11:0] ref_sig, // Reference signal (8MHz)
    input wire [11:0] ref_sig_q, // Quadrature reference
    output reg signed [15:0] phase_out, // Phase in 0.01 degrees
    output reg phase_valid     // Valid flag
);

// State encoding (binary)
parameter [1:0] 
    IDLE       = 2'b00,
    ACCUMULATE = 2'b01,
    CALCULATE  = 2'b10;

reg [1:0] state;      // Current state
reg [1:0] next_state; // Next state

// Product registers
reg signed [23:0] i_product, q_product;
reg signed [31:0] i_accum, q_accum;
reg [9:0] accum_counter;

// State transition logic
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        i_accum <= 0;
        q_accum <= 0;
        accum_counter <= 0;
        phase_out <= 0;
        phase_valid <= 0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                i_accum <= 0;
                q_accum <= 0;
                accum_counter <= 0;
                phase_valid <= 0;
            end
            
            ACCUMULATE: begin
                i_product <= $signed(signal) * $signed(ref_sig);
                q_product <= $signed(signal) * $signed(ref_sig_q);
                
                i_accum <= i_accum + i_product;
                q_accum <= q_accum + q_product;
                
                accum_counter <= accum_counter + 1;
            end
            
            CALCULATE: begin
                // Simple phase approximation
                if (i_accum == 0) begin
                    phase_out <= (q_accum > 0) ? 16'sd9000 : -16'sd9000;
                end else begin
                    phase_out <= (q_accum * 1000) / i_accum;
                end
                phase_valid <= 1;
            end
        endcase
    end
end

// Next state logic
always @(*) begin
    case (state)
        IDLE:       next_state = ACCUMULATE;
        ACCUMULATE: next_state = (accum_counter == 256) ? CALCULATE : ACCUMULATE;
        CALCULATE:  next_state = IDLE;
        default:    next_state = IDLE;
    endcase
end

endmodule