`timescale 1ns/1ps

module tb_async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4,
    parameter real WHALF = 5.0,     // wclk half period (ns)
    parameter real RHALF = 8.5      // rclk half period (ns)
);
    localparam DEPTH = 2**ADDR_WIDTH;

    reg wclk;
    reg wrst_n;
    reg wr_en;
    reg [DATA_WIDTH-1:0] wr_data;
    wire full;
    reg rclk;
    reg rrst_n;
    reg rd_en;
    wire [DATA_WIDTH-1:0] rd_data;
    wire empty;

    async_fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) dut (
        .wclk(wclk),
        .wrst_n(wrst_n),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .full(full),
        .rclk(rclk),
        .rrst_n(rrst_n),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .empty(empty)
    );
    integer test_num = 0;
    integer pass_n = 0;
    integer fail_n = 0;


    task check(input [31:0] got, input [31:0] exp);
        begin
            test_num = test_num + 1;
            if (got === exp) begin
                $display("PASS %0d got=%h", test_num, got);
                pass_n = pass_n + 1;
            end
            else begin
                $display("FAIL %0d got=%h exp=%h", test_num, got, exp);
                fail_n = fail_n + 1;
            end
        end
    endtask


    initial begin
        wclk = 0;
        rclk = 0;
    end

    always #(WHALF) wclk = ~wclk;
    always #(RHALF) rclk = ~rclk;


    integer i;

    // ---------------- T4 declarations ----------------
    localparam N_WORDS = 1000;
    integer seed;
    reg [DATA_WIDTH-1:0] q [0:N_WORDS-1];  // reference queue
    integer head, tail;                     // head: next pop, tail: next push
    integer n_wr, n_rd, t4_err;
    reg [DATA_WIDTH-1:0] exp_data;

    // Print %t in ns
    initial $timeformat(-9, 1, " ns", 10);

    // Watchdog: stop if the DUT gets stuck
    initial begin
        #1_000_000;
        $display("TIMEOUT at %0t: n_wr=%0d n_rd=%0d", $time, n_wr, n_rd);
        $display("%0d passed, %0d failed, TIMEOUT", pass_n, fail_n);
        $finish;
    end

    initial begin
        wr_en = 0;
        wr_data = 0;
        rd_en = 0;


        // T1
        wrst_n = 0;
        rrst_n = 0;
        @(negedge wclk);
        #1;
        wrst_n = 1;
        check(full, 0);
        @(negedge rclk);
        #1;
        rrst_n = 1;
        check(empty, 1);

        // T2
        for(i=0; i<DEPTH+1; i=i+1) begin
            @(posedge wclk);
            #1;
            wr_en = 1;
            wr_data = i;
            #1;
            check(full, (i >= DEPTH));
        end
        @(posedge wclk);
        #1;
        wr_en = 0;

        // T3
        for(i=0; i<DEPTH+1; i=i+1) begin
            @(posedge rclk);
            #1;
            rd_en = 1;
            #1;
            if (i < DEPTH) check(rd_data, i);
            check(empty, (i >= DEPTH));
        end
        @(posedge rclk);
        #1;
        rd_en = 0;

        // T4: random writes and reads at the same time, checked against a reference queue
        if (!$value$plusargs("seed=%d", seed)) seed = 1;
        $display("T4: seed=%0d, %0d words, DEPTH=%0d, wclk=%0.1f ns, rclk=%0.1f ns",
                 seed, N_WORDS, DEPTH, 2*WHALF, 2*RHALF);

        head = 0; tail = 0; n_wr = 0; n_rd = 0; t4_err = 0;

        fork
            begin : writer
                while (n_wr < N_WORDS) begin
                    @(negedge wclk);                      // drive away from the edge
                    wr_en   = (($random(seed) & 3) != 0); // 75% of cycles
                    wr_data = $random(seed);
                    @(posedge wclk);                      // check with pre-edge values
                    if (wr_en && !full) begin
                        q[tail] = wr_data;
                        tail = tail + 1;
                        n_wr = n_wr + 1;
                        if (tail - head > DEPTH) begin
                            $display("T4 FAIL: overflow, %0d words in a %0d-deep FIFO at %0t",
                                     tail - head, DEPTH, $time);
                            t4_err = t4_err + 1;
                        end
                    end
                end
                @(negedge wclk);
                wr_en = 0;
            end

            begin : reader
                while (n_rd < N_WORDS) begin
                    @(negedge rclk);
                    rd_en = (($random(seed) & 3) != 0);
                    @(posedge rclk);
                    if (rd_en && !empty) begin
                        if (head == tail) begin
                            $display("T4 FAIL: underflow, read accepted with nothing written, at %0t", $time);
                            t4_err = t4_err + 1;
                        end else begin
                            exp_data = q[head];           // FWFT: rd_data before the edge is this word
                            head = head + 1;
                            if (rd_data !== exp_data) begin
                                if (t4_err < 10)
                                    $display("T4 FAIL: read %0d got=%h exp=%h at %0t",
                                             n_rd, rd_data, exp_data, $time);
                                t4_err = t4_err + 1;
                            end
                        end
                        n_rd = n_rd + 1;
                    end
                end
                @(negedge rclk);
                rd_en = 0;
            end
        join

        $display("T4: %0d writes, %0d reads, %0d errors", n_wr, n_rd, t4_err);
        
        test_num = test_num + 1;
        if (t4_err == 0)
            pass_n = pass_n + 1;
        else
            fail_n = fail_n + 1;

        #20;
        $display("%0d passed, %0d failed", pass_n, fail_n);
        $finish;
    end

endmodule