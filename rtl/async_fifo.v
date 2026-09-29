module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    input wire wclk,
    input wire wrst_n,
    input wire wr_en,
    input wire [DATA_WIDTH-1:0] wr_data,
    output reg full,
    
    input wire rclk,
    input wire rrst_n,
    input wire rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output reg empty
);

    localparam DEPTH = 2**ADDR_WIDTH;
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];


    reg [ADDR_WIDTH:0] wr_ptr;
    reg [ADDR_WIDTH:0] rd_ptr;

    reg [ADDR_WIDTH:0] wr_ptr_sync1, wr_ptr_sync2;
    reg [ADDR_WIDTH:0] rd_ptr_sync1, rd_ptr_sync2;

    wire [ADDR_WIDTH:0] wr_ptr_next = wr_ptr + (wr_en && !full);
    wire [ADDR_WIDTH:0] rd_ptr_next = rd_ptr + (rd_en && !empty);

    wire [ADDR_WIDTH:0] wr_ptr_next_gray = wr_ptr_next ^ (wr_ptr_next >> 1);
    wire [ADDR_WIDTH:0] rd_ptr_next_gray = rd_ptr_next ^ (rd_ptr_next >> 1);

    reg [ADDR_WIDTH:0] wr_gray, rd_gray;

    
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            rd_ptr_sync1 <= 0;
            rd_ptr_sync2 <= 0;
            wr_gray <= 0;
        end
        else begin
            wr_gray <= wr_ptr_next_gray;
            rd_ptr_sync1 <= rd_gray;
            rd_ptr_sync2 <= rd_ptr_sync1;
        end
    end

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            wr_ptr_sync1 <= 0;
            wr_ptr_sync2 <= 0;
            rd_gray <= 0;
        end
        else begin
            rd_gray <= rd_ptr_next_gray;
            wr_ptr_sync1 <= wr_gray;
            wr_ptr_sync2 <= wr_ptr_sync1;
        end
    end



    
    
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            full <= 0;
            wr_ptr <= 0;
        end
        else begin
            if (wr_en && !full) begin
                mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
                wr_ptr <= wr_ptr + 1;
            end
            full <= (wr_ptr_next_gray == {~rd_ptr_sync2[ADDR_WIDTH:ADDR_WIDTH-1], rd_ptr_sync2[ADDR_WIDTH-2:0]});
        end
    end
    
    
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            empty <= 1;
            rd_ptr <= 0;
        end
        else begin
            if (rd_en && !empty) begin
                rd_ptr <= rd_ptr + 1;
            end
            empty <= (wr_ptr_sync2 == rd_ptr_next_gray);
        end
    end

    
    assign rd_data = mem[rd_ptr[ADDR_WIDTH-1:0]];
    


endmodule
