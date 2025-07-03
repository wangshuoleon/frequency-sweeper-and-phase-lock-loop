module fifo_80_to_8 #(
    parameter INPUT_WIDTH = 80,
    parameter OUTPUT_WIDTH = 8,
    parameter DEPTH = 255  // Number of 80-bit words stored
)(
    input wire clk,
    input wire reset,
    // 80-bit input interface
    input wire wr_en,
    input wire [INPUT_WIDTH-1:0] din,
    output wire full,
    // 8-bit output interface
    input wire rd_en,
    output wire [OUTPUT_WIDTH-1:0] dout,
    output wire empty,
    output wire [7:0] bytes_available  // Count of available bytes
);
    // Storage for 80-bit words
    reg [INPUT_WIDTH-1:0] mem [0:DEPTH-1];
    reg [$clog2(DEPTH):0] wr_ptr, rd_ptr;
    
    // Output conversion registers
    reg [INPUT_WIDTH-1:0] current_word;
    reg [3:0] byte_pos;  // 80/8=10 bytes per word (needs 4 bits)
    reg word_valid;
    
    // FIFO control signals
    wire fifo_read;
    assign full = (wr_ptr == rd_ptr + DEPTH);
    assign empty = (wr_ptr == rd_ptr) && !word_valid;
    assign fifo_read = (byte_pos == 4'd9) && rd_en;
    
    // Bytes available calculation
    assign bytes_available = 
        (wr_ptr - rd_ptr) * 10 + byte_pos;  // 10 bytes per 80-bit word
    
    // Output selection
    assign dout = current_word[byte_pos*8 +: 8];
    
    // Main FIFO control
    always @(posedge clk) begin
        if (reset) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            byte_pos <= 0;
            word_valid <= 0;
        end else begin
            // Write side (80-bit)
            if (wr_en && !full) begin
                mem[wr_ptr[$clog2(DEPTH)-1:0]] <= din;
                wr_ptr <= wr_ptr + 1;
            end
            
            // Read side (8-bit)
            if (rd_en && !empty) begin
                if (byte_pos == 4'd9) begin
                    byte_pos <= 0;
                    word_valid <= 0;
                end else begin
                    byte_pos <= byte_pos + 1;
                end
            end
            
            // Load new word when needed
            if (fifo_read || !word_valid) begin
                if (wr_ptr != rd_ptr) begin
                    current_word <= mem[rd_ptr[$clog2(DEPTH)-1:0]];
                    rd_ptr <= rd_ptr + 1;
                    word_valid <= 1;
                end
            end
        end
    end
endmodule