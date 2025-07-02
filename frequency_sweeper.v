module frequency_sweeper (
    input wire clk,                // 50 MHz clock
    input wire reset,              // Active-high reset
    // FIFO Interface
    input wire [87:0] fifo_data,   // Instruction from FIFO (expanded to 88 bits)
    input wire fifo_empty,         // FIFO status
    output reg fifo_rd_en,         // FIFO read enable
    // DDS Control Interface
    output reg [31:0] dds_freq,    // Current frequency tuning word
    output reg sweep_start,        // Pulse to start sweep
    output reg sweep_done,         // Pulse when sweep completes
    // PLL Interface
    input wire [15:0] phase_error, // Phase error from phase detector (signed)
    output reg pll_enable          // PLL control enable
);

    // Instruction registers (expanded)
    reg [31:0] init_freq;
    reg [15:0] cycles_per_step;
    reg [31:0] freq_step;
    reg [87:0] instr_buffer;              
    
    // PLL control registers
    reg [31:0] pll_integral;
    reg [31:0] pll_proportional;
    parameter PLL_KI = 32'h00001000; // Integral gain
    parameter PLL_KP = 32'h00002000; // Proportional gain
    
    // Sweep control
    reg [15:0] cycle_counter;
    reg [7:0] step_counter;        // 255 steps max (8-bit)
    reg [2:0] state;               // Expanded to 3 bits for extra states
    // Pipeline registers
    reg [2:0] decode_stage;        // decode state
    reg [2:0] load_cycles;       // load cycles for the instruction

    // State encoding
    localparam IDLE      = 3'b000;
    localparam LOAD      = 3'b001;
    localparam DECODE    = 3'b111;
    localparam SWEEP     = 3'b010;
    localparam PLL_LOCK  = 3'b011;
    localparam PLL_TRACK = 3'b100;

    // State machine
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            fifo_rd_en <= 0;
            sweep_start <= 0;
            sweep_done <= 0;
            pll_enable <= 0;
            dds_freq <= 0;
            pll_integral <= 0;
            pll_proportional <= 0;
        end else begin
            case (state)
                IDLE: begin
                    sweep_done <= 0;
                    pll_enable <= 0;
                    if (fifo_empty) begin
                        // hand shake with FIFO
                        fifo_rd_en <= 1;
                        state <= LOAD;
                        // reset the load counter
                        load_cycles <= 0;
                    end
                end
                
                
                LOAD: begin
                    fifo_rd_en <= 0;
                    // load the instruction
                    // this path could be set as multiple cycles in timing constraints
                    instr_buffer <= fifo_data;
                    // reset the decode stage to 0
                    decode_stage <= 0;
                    if (load_cycles < 4) begin
                        load_cycles <= load_cycles + 1;
                    end else begin
                        load_cycles <= 0;
                        state <= DECODE; // go to decode state after loading
                    end
                end

                DECODE: begin
                  case (decode_stage)
                        3'd0: begin
                        init_freq <= instr_buffer[79:48];
                        decode_stage <= 3'd1;
                    end
                        3'd1: begin
                        cycles_per_step <= instr_buffer[47:32];
                        decode_stage <= 3'd2;
                    end
                        3'd2: begin
                        freq_step <= instr_buffer[31:0];
                        decode_stage <= 3'd3;
                    end
                        3'd3: begin
                        // mode_select <= instr_buffer[87];
                        // 0 = Sweep, 1 = PLL
                        dds_freq <= init_freq;  // Initialize frequency
                        cycle_counter <= 0;
                        step_counter <= 0;
                        if (instr_buffer[87]) begin
                            pll_integral <= 0;
                            state <= PLL_LOCK;
                        end else begin
                            sweep_start <= 1;
                            state <= SWEEP;
                        end
                    end
                    endcase
                 end

                SWEEP: begin
                    sweep_start <= 0;
                    if (cycle_counter < cycles_per_step) begin
                        cycle_counter <= cycle_counter + 1;
                    end else begin
                        cycle_counter <= 0;
                        if (step_counter < 255) begin
                            step_counter <= step_counter + 1;
                            dds_freq <= dds_freq + freq_step;
                        end else begin
                            sweep_done <= 1;
                            state <= IDLE;
                        end
                    end
                end
                
                PLL_LOCK: begin
                    // Initial lock state - wait for stable phase
                    pll_enable <= 1;
                    if (cycle_counter < 1023) begin
                        cycle_counter <= cycle_counter + 1;
                    end else begin
                        state <= PLL_TRACK;
                        cycle_counter <= 0;
                    end
                end
                
                PLL_TRACK: begin
                    // Active PLL tracking state
                    if (cycle_counter < 15) begin
                        cycle_counter <= cycle_counter + 1;
                    end else begin
                        cycle_counter <= 0;
                        // PI controller implementation
                        pll_proportional <= $signed(phase_error) * $signed(PLL_KP);
                        pll_integral <= pll_integral + ($signed(phase_error) * $signed(PLL_KI));
                        dds_freq <= init_freq + pll_proportional + pll_integral;
                    end
                end
            endcase
        end
    end
endmodule