module frequency_sweeper #(
   parameter DISSIPATION_MEASUREMENT_CYCLES = 16'd200 // Max cycles for dissipation measurement

)(
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
	 output reg frequency_update, // Pulse when new frequency is valid
    // PLL Interface
    input wire [15:0] phase_error, // Phase error from phase detector (signed)
    output reg Dissipation_Measurement_enable    //signal for mux the tx  
);

    // Instruction registers (expanded)
    reg [31:0] init_freq;
    reg [15:0] cycles_per_step;
    reg [31:0] freq_step;
    reg [87:0] instr_buffer;              
    

    
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
    localparam Dissipation_Measurement = 3'b100;


    // State machine
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            fifo_rd_en <= 0;
            sweep_start <= 0;
            sweep_done <= 0;
            dds_freq <= 0;
            Dissipation_Measurement_enable <= 0;
        end else begin
            case (state)
                IDLE: begin
                    sweep_done <= 0;
  
						  frequency_update <= 0; // No new frequency update during sweep
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
						frequency_update <= 1; // Indicate new frequency is valid
                         // Instruction decoder mux
                        case (instr_buffer[87:80])
                                8'd0: begin
                                sweep_start <= 1;
                                state <= SWEEP;
                                end
                                8'd255: begin
                                state <= PLL_LOCK;
                                end
                                8'd1: begin
                                state <= Dissipation_Measurement;
                                end
                                default: begin
                                state <= IDLE; // fallback
                                end
                        endcase
                        end
                        
                    endcase
                
                 end
					  

                SWEEP: begin
                    sweep_start <= 0;
                    if (cycle_counter < cycles_per_step) begin
                        cycle_counter <= cycle_counter + 1;
								frequency_update <= 0; // No new frequency update during sweep
                    end else begin
                        cycle_counter <= 0;
                        if (step_counter < 8'd255) begin
                            step_counter <= step_counter + 1;
                            dds_freq <= dds_freq + freq_step;
									 frequency_update <= 1; // New frequency is valid
                        end else begin
                            sweep_done <= 1;
                            state <= IDLE;
                        end
                    end
                end
                
                PLL_LOCK: begin
                    // Initial lock state - wait for stable phase
                    
						  // the max. integration time of 65535
                    if (cycle_counter < 16'hFFFE) begin
                        cycle_counter <= cycle_counter + 1;
						frequency_update <= 0; // No new frequency update during sweep
                    end else begin
                        state <= IDLE; // Tran
						// reset counter
                        cycle_counter <= 0;
						frequency_update <= 1; // No new frequency update during sweep
								
								
                    end
                end
                
                Dissipation_Measurement: begin
                    // set a flag signal for dissipation measurement 
                    Dissipation_Measurement_enable <= 1;

                    if (cycle_counter < DISSIPATION_MEASUREMENT_CYCLES) begin
                        cycle_counter <= cycle_counter + 1;
                    end else begin
                        cycle_counter <= 0;
                        Dissipation_Measurement_enable <= 0; // Reset the flag
                    end
                end
            endcase
        end
    end
endmodule