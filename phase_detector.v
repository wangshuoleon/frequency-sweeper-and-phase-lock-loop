module phase_detector (
    input wire clk,            // 50 MHz clock
    input wire reset,          // Active-high reset
    input wire trigger,        // Rising edge triggers output and reset
    input wire [11:0] signal,  // Input signal to measure, input from 12 bit ADC (50MHz)
    input wire [7:0] ref_sig, // Reference signal (8MHz)
    input wire [7:0] ref_sig_q, // Quadrature reference
    output reg [39:0] q_component, // Phase in 0.01 degrees
    output reg [39:0] i_component,    // output magnitute signal
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
reg signed [39:0] i_accum, q_accum;
reg trigger_delay;

// Detect rising edge of trigger
reg trigger_delay2;


// State transition logic
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        i_accum <= 0;
        q_accum <= 0;
        q_component <= 0;
        i_component <= 0;
        data_valid <= 0;
        trigger_delay <= 0;
        i_product<=0;
        q_product<=0;
    end else begin
        trigger_delay2 <= trigger;
        trigger_delay <= trigger_delay2;
        
        case (state)
            IDLE: begin
                data_valid <= 0;
                if (trigger) begin
                    i_accum <= 0;
                    q_accum <= 0;
                    state <= ACCUMULATE;
                end
            end
            
            ACCUMULATE: begin
                // Multiply and accumulate
                data_valid<=0;
                i_product <= $signed(signal) * $signed(ref_sig);
                q_product <= $signed(signal) * $signed(ref_sig_q);
                
                i_accum <= i_accum + i_product;
                q_accum <= q_accum + q_product;
                
                if (trigger) begin
                    state <= HOLD;
                end
            end
            
            HOLD: begin
                // directly output Q and I component
                q_component<=q_accum;
                i_component<=i_accum;
                q_accum <= 0; // Reset accumulators
                i_accum <= 0;   
                data_valid <= 1;
                state<= ACCUMULATE; // go back to accumulate state
                
            end
        endcase
    end
end

endmodule

