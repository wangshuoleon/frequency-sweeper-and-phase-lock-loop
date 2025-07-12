module fifo16to8 #(
    parameter DEPTH = 16  // number of 16-bit words
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        write_en,
    input  logic [15:0] data_in,
    input  logic        read_en,
    output logic [7:0]  data_out,
    output logic        empty,
    output logic        full
);

    logic [15:0] mem [0:DEPTH-1];
    logic [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
    logic read_half;  // 0: output lower byte; 1: output upper byte
    logic [$clog2(DEPTH+1):0] count;  // number of valid 16-bit words

    // Full and empty flags
    assign full  = (count == DEPTH);
    assign empty = (count == 0) && (read_half == 0);

    // Write logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr <= 0;
            count  <= 0;
        end else if (write_en && !full) begin
            mem[wr_ptr] <= data_in;
            wr_ptr <= wr_ptr + 1;
            count  <= count + 1;
        end
    end

    // Read logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            rd_ptr    <= 0;
            read_half <= 0;
            data_out  <= 8'd0;
        end else if (read_en && !empty) begin
            if (read_half == 0) begin
                data_out <= mem[rd_ptr][7:0];   // lower byte
                read_half <= 1;
            end else begin
                data_out <= mem[rd_ptr][15:8];  // upper byte
                read_half <= 0;
                rd_ptr <= rd_ptr + 1;
                count  <= count - 1;
            end
        end
    end

endmodule
