module fifo #(
    parameter WIDTH = 8,      // Data width (bits)
    parameter DEPTH = 10,     // FIFO depth (entries)
    parameter ALMOST_FULL_THRESH  = DEPTH - 2,  // Almost full threshold
    parameter ALMOST_EMPTY_THRESH = 2,           // Almost empty threshold
    parameter READ_SCALAR=10
) (
    input  logic                clk,
    input  logic                reset,      // Active-high reset
    // Write interface
    input  logic                wr_en,
    input  logic [WIDTH-1:0]    din,
    output logic                full,
    output logic                almost_full,
    // Read interface
    input  logic                rd_en,
    output logic [WIDTH*READ_SCALAR-1:0]    dout,
    output logic                empty,
    output logic                almost_empty,
    // Optional status
    output logic [$clog2(DEPTH):0] count  // Current fill count
);

    // Memory array
    logic [WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers
    logic [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
    logic [$clog2(DEPTH):0]   ptr_diff;  // Extra bit for full/empty detection

    // =============================================
    // FIFO Control Logic
    // =============================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            wr_ptr      <= 0;
            rd_ptr      <= 0;
            ptr_diff    <= 0;
        end else begin
            // Write operation
            if (wr_en && !full) begin
                mem[wr_ptr] <= din;
                wr_ptr      <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
            end

            // Read operation
            if (rd_en && !empty) begin
                dout       <= mem[rd_ptr];
                rd_ptr     <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + READ_SCALAR;
            end

            // Pointer difference (for count/full/empty)
            case ({wr_en && !full, rd_en && !empty})
                2'b01: ptr_diff <= ptr_diff - 1;  // Read only
                2'b10: ptr_diff <= ptr_diff + 1;  // Write only
                default: ;                        // No change or read+write
            endcase
        end
    end

    // =============================================
    // Status Flags
    // =============================================
    assign full          = (ptr_diff == DEPTH);
    assign empty         = (ptr_diff == 0);
    assign almost_full   = (ptr_diff >= ALMOST_FULL_THRESH);
    assign almost_empty  = (ptr_diff <= ALMOST_EMPTY_THRESH);
    assign count         = ptr_diff;

endmodule