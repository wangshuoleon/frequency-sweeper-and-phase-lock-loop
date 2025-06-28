module fifo #(
    parameter WIDTH = 8,               // Data width (bits)
    parameter DEPTH = 11,              // FIFO depth (entries)
    parameter ALMOST_FULL_THRESH = DEPTH - 2,
    parameter ALMOST_EMPTY_THRESH = 2,
    parameter READ_SCALAR = 11         // Number of bytes to output at once
) (
    input  logic clk,
    input  logic reset,
    // Write interface
    input  logic wr_en,
    input  logic [WIDTH-1:0] din,
    output logic full,
    output logic almost_full,
    // Read interface
    input  logic rd_en,
    output logic [WIDTH*READ_SCALAR-1:0] dout,
    output logic empty,
    output logic almost_empty,
    output logic [$clog2(DEPTH):0] count
);

    // Memory array - now stores multiple words per entry
    logic [WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers
    logic [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
    logic [$clog2(DEPTH):0] ptr_diff;

    // Read data generation
    always_comb begin
        for (int i = 0; i < READ_SCALAR; i = i + 1) begin
            // Use modulo arithmetic for circular buffer
            dout[i*WIDTH +: WIDTH] = mem[(rd_ptr + i) % DEPTH];
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            ptr_diff <= 0;
        end else begin
            // Write operation (single byte)
            if (wr_en && !full) begin
                mem[wr_ptr] <= din;
                wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
            end

            // Read operation (multiple bytes)
            if (rd_en && !empty) begin
                rd_ptr <= (rd_ptr + READ_SCALAR) % DEPTH;
            end

            // Pointer difference calculation
            case ({wr_en && !full, rd_en && !empty})
                2'b01: ptr_diff <= (ptr_diff >= READ_SCALAR) ? ptr_diff - READ_SCALAR : 0;
                2'b10: ptr_diff <= ptr_diff + 1;
                2'b11: ptr_diff <= (ptr_diff >= READ_SCALAR) ? ptr_diff + 1 - READ_SCALAR : 1;
                default: ;
            endcase
        end
    end

    // Status flags
    assign full = (ptr_diff == DEPTH);
    assign empty = (ptr_diff < READ_SCALAR); // Not enough data for a full read
    assign almost_full = (ptr_diff >= ALMOST_FULL_THRESH);
    assign almost_empty = (ptr_diff <= ALMOST_EMPTY_THRESH);
    assign count = ptr_diff;

    // Parameter validation
    initial begin
        if (READ_SCALAR > DEPTH) begin
            $error("READ_SCALAR (%0d) cannot exceed DEPTH (%0d)", READ_SCALAR, DEPTH);
            $finish;
        end
    end
endmodule