module frequency_sweeper (
    input wire clk,                // 50 MHz clock
    input wire reset,              // Active-high reset
    // FIFO Interface
    input wire [79:0] fifo_data,   // Instruction from FIFO
    input wire fifo_empty,         // FIFO status
    output reg fifo_rd_en,         // FIFO read enable
    // DDS Control Interface
    output reg [31:0] dds_freq,    // Current frequency tuning word
    output reg sweep_start,        // Pulse to start sweep
    output reg sweep_done          // Pulse when sweep completes
);

    // Instruction registers
    reg [31:0] init_freq;
    reg [15:0] cycles_per_step;
    reg [31:0] freq_step;
    

    // Sweep control
    reg [15:0] cycle_counter;
    reg [7:0] step_counter;       // 2^10 = 1024 steps max
    reg [1:0] state;

    // State encoding
    localparam IDLE      = 2'b00;
    localparam LOAD      = 2'b01;
    localparam SWEEP     = 2'b10;


    assign dds_freq_wire=dds_freq[31:0];

    // State machine
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            fifo_rd_en <= 0;
            sweep_start <= 0;
            sweep_done <= 0;
            dds_freq <= 0;
        end else begin
            case (state)
                IDLE: begin
                    sweep_done <= 0;
                    if (!fifo_empty) begin
                        fifo_rd_en <= 1;
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    fifo_rd_en <= 0;
                     {init_freq, cycles_per_step, freq_step} <= fifo_data;
                    // Change this:
                    // {init_freq, cycles_per_step, freq_step} <= fifo_data;

                    // To this explicit version:
                    // init_freq       <= fifo_data[79:48];  // Bits [79:48] (32 bits)
                    // cycles_per_step <= fifo_data[47:32];  // Bits [47:32] (16 bits)
                    // freq_step       <= fifo_data[31:0];   // Bits [31:0] (32 bits)
                    


                    dds_freq <= fifo_data[79:48];
                    cycle_counter <= 0;
                    step_counter <= 0;
                    sweep_start <= 1;
                    state <= SWEEP;
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
            endcase
        end
    end
endmodule