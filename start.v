// Variant 1 : y = a ^ 2 + b ^ (1/3)
// Restrictions: 1 summation, 2 multiplications

module summ (
    input clk,
    input rst,
    input start,
    input [15:0] a,
    input [15:0] b,
    output reg ready,
    output reg [15:0] y
);
    always @(posedge clk) begin
        if (rst) begin
            y <= 16'd0;
            ready <= 1'b0;
        end else if (start) begin
            y <= a + b;
            ready <= 1'b1;
            // $display();
            // $write(" In summator: ",a + b, a, b);
            // $display();
        end else begin
            ready <= 1'b0;
        end
    end
endmodule

module subs (
    input clk,
    input rst,
    input start,
    input [15:0] a,
    input [15:0] b,
    output reg ready,
    output reg [15:0] y
);
    always @(posedge clk) begin
        if (rst) begin
            y <= 16'd0;
            ready <= 1'b0;
        end else if (start) begin
            y <= a - b;
            ready <= 1'b1;
        end else begin
            ready <= 1'b0;
        end
    end
endmodule


module mult(
    input clk,
    input rst,
    input start,
    input [15:0] a_in,
    input [15:0] b_in,
    output reg [15:0] f_out,
    output reg ready
);
    localparam IDLE = 1'b0;
    localparam WORK = 1'b1;
    
    reg state;
    reg [15:0] sum;
    reg [15:0] counter;
    
    reg summ_start;
    wire summ_ready;
    wire [15:0] summ_y;
    reg [15:0] summ_a, summ_b;
    
    summ summ_inst (
        .clk(clk),
        .rst(rst),
        .start(summ_start),
        .a(summ_a),
        .b(summ_b),
        .ready(summ_ready),
        .y(summ_y)
    );
    
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            sum <= 16'd0;
            counter <= 16'd0;
            f_out <= 16'd0;
            ready <= 1'b0;
            summ_start <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        sum <= 16'd0;
                        counter <= 16'd0;
                        summ_a <= 16'd0;
                        summ_b <= a_in;
                        summ_start <= 1'b1;
                        state <= WORK;
                        ready <= 1'b0;
                        
                    end
                end
                WORK: begin
                    summ_start <= 1'b0; // Deassert start after one cycle
                    if (summ_ready) begin
                        // $display();
                        // $write(" In mult: ",a_in, counter, summ_y);
                        // $write(" In mult: ",a_in, b_in);
                        // $display();
                        counter <= counter + 1;
                        if (counter < b_in) begin
                            summ_a <= summ_y;
                            summ_b <= a_in;
                            summ_start <= 1'b1;
                        end else begin
                            f_out <= sum;
                            ready <= 1'b1;
                            state <= IDLE;
                        end
                        sum <= summ_y;
                    end
                end
            endcase
        end
    end
endmodule

module cubicroot(
    input clk,
    input rst,
    input start,
    input [15:0] x_in,
    output reg [15:0] y_out,
    output reg ready
);
    // State encoding
    localparam IDLE          = 4'd0;
    localparam INIT          = 4'd1;
    localparam SHIFT_Y       = 4'd2;
    localparam COMPUTE_B1    = 4'd3;
    localparam COMPUTE_B1_2  = 4'd4;
    localparam COMPUTE_B2    = 4'd5;
    localparam COMPUTE_B3    = 4'd6;
    localparam COMPUTE_B4    = 4'd7;
    localparam SHIFT_B       = 4'd8;
    localparam SHIFT_B2      = 4'd9;
    localparam COMPARE       = 4'd10;
    localparam UPDATE_X_Y    = 4'd11;
    localparam SAVE_Y        = 4'd12;
    localparam DECREMENT_S   = 4'd13;
    localparam DONE          = 4'd14;

    reg [3:0] state;
    reg [15:0] x;
    reg [15:0] y;
    reg [31:0] b;
    reg [5:0] s;
    reg [15:0] temp1, temp2, temp3;

    // Control signals for modules
    reg summ_start;
    wire summ_ready;
    wire [15:0] summ_y;
    reg [15:0] summ_a, summ_b;

    reg diff_start;
    wire diff_ready;
    wire [15:0] diff_y;
    reg [15:0] diff_a, diff_b;

    reg mult1_start, mult2_start;
    wire mult1_ready, mult2_ready;
    wire [15:0] mult1_f_out, mult2_f_out;
    reg [15:0] mult1_a_in, mult1_b_in;
    reg [15:0] mult2_a_in, mult2_b_in;

    summ summ_inst (
        .clk(clk),
        .rst(rst),
        .start(summ_start),
        .a(summ_a),
        .b(summ_b),
        .ready(summ_ready),
        .y(summ_y)
    );

    subs diff_inst (
        .clk(clk),
        .rst(rst),
        .start(diff_start),
        .a(diff_a),
        .b(diff_b),
        .ready(diff_ready),
        .y(diff_y)
    );

    mult mult1_inst (
        .clk(clk),
        .rst(rst),
        .start(mult1_start),
        .a_in(mult1_a_in),
        .b_in(mult1_b_in),
        .f_out(mult1_f_out),
        .ready(mult1_ready)
    );

    mult mult2_inst (
        .clk(clk),
        .rst(rst),
        .start(mult2_start),
        .a_in(mult2_a_in),
        .b_in(mult2_b_in),
        .f_out(mult2_f_out),
        .ready(mult2_ready)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            x <= 16'd0;
            y <= 16'd0;
            s <= 6'd0;
            b <= 32'b0;
            ready <= 1'b0;
            y_out <= 16'd0;
            summ_start <= 1'b0;
            diff_start <= 1'b0;
            mult1_start <= 1'b0;
            mult2_start <= 1'b0;
            temp1 <= 16'd0;
            temp2 <= 16'd0;
            temp3 <= 16'd0;
            
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b0;
                    if (start) begin
                        x <= x_in;
                        y <= 16'd0;
                        s <= 6'd30;
                        state <= SHIFT_Y;
                    end
                end
                SHIFT_Y: begin
                    $display();
                    $display("-=-=-=-=-=-=-=-=-");
                    $write(" s:%d", s);
                    $write(" y:%d", y);

                    // y = 2 * y
                    mult1_a_in <= y;
                    mult1_b_in <= 16'd2; // In the end it will be 1 * 2 = 1 I dont know why 
                    mult1_start <= 1'b1;
                    state <= COMPUTE_B1;
                end
                COMPUTE_B1: begin
                    mult1_start <= 1'b0;
                    if (mult1_ready) begin
                        $write(" mult:%d", mult1_f_out);
                        if (mult1_f_out == 16'd3) begin
                            $display("");
                            $display("  Etra Stop  ");
                            $display("");
                            $finish;
                        end
                        y <= mult1_f_out;
                        state <= COMPUTE_B1_2;
                    end
                end
                COMPUTE_B1_2: begin
                    // temp1 = y + 1
                    summ_a <= y;
                    summ_b <= 16'd1;
                    summ_start <= 1'b1;
                    state <= COMPUTE_B2;
                end
                COMPUTE_B2: begin
                    summ_start <= 1'b0;
                    if (summ_ready) begin
                        $write(" 2y:%d", y);
                        temp1 <= summ_y;
                        

                        // temp2 = y * temp1
                        mult1_a_in <= y;
                        mult1_b_in <= temp1;
                        mult1_start <= 1'b1;
                        state <= COMPUTE_B3;
                    end
                end
                COMPUTE_B3: begin
                    mult1_start <= 1'b0;
                    if (mult1_ready) begin
                        $write(" temp1:", temp1);
                        temp2 <= mult1_f_out;
                        

                        // temp3 = 3 * temp2
                        mult1_a_in <= 16'd3;
                        mult1_b_in <= temp2;

                        mult1_start <= 1'b1;
                        state <= COMPUTE_B4;
                    end
                end
                COMPUTE_B4: begin
                    mult1_start <= 1'b0;
                    if (mult1_ready) begin
                        $write(" temp2:", temp2);
                        temp3 <= mult1_f_out;
                        

                        // b = temp3 + 1
                        

                        summ_a <= temp3;
                        summ_b <= 16'd1;
                        summ_start <= 1'b1;
                        state <= SHIFT_B;
                    end
                end
                SHIFT_B: begin
                    summ_start <= 1'b0;
                    if (summ_ready) begin
                        b <= summ_y;
                        
                        state <= SHIFT_B2;
                    end
                end
                SHIFT_B2: begin
                    $write(" b:", b);
                    b <= b << s;
                    
                    state <= COMPARE;
                end
                COMPARE: begin
                    $write(" b<<:", b);
                    if (x >= b) begin
                        $write(" x>=b");
                        // x = x - b
                        diff_a <= x;
                        diff_b <= b;
                        diff_start <= 1'b1;
                        state <= UPDATE_X_Y;
                    end else begin
                        state <= DECREMENT_S;
                    end
                    
                end
                UPDATE_X_Y: begin
                    diff_start <= 1'b0;
                    if (diff_ready) begin
                        x <= diff_y;
                        // y = y + 1
                        summ_a <= y;
                        summ_b <= 16'd1;
                        summ_start <= 1'b1;
                        state <= SAVE_Y;
                    end
                end
                SAVE_Y: begin
                    summ_start <= 1'b0;
                    if (summ_ready) begin
                        $write(" x:", x);
                        y <= summ_y;
                        state <= DECREMENT_S;
                    end
                end
                DECREMENT_S: begin
                
                    if (s >= 6'd3) begin
                        s <= s - 6'd3;
                        state <= SHIFT_Y;
                    end else begin
                        state <= DONE;
                    end
                end
                DONE: begin
                    y_out <= y;
                    ready <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule

module clock_gen(
    output reg clk
);
    initial begin
        clk = 1'b0;
        forever #1 clk = ~clk;
    end
endmodule

module cubicroot_test;
    wire clk;
    reg rst;
    reg start;
    reg [15:0] x_in;
    wire [15:0] y_out;
    wire ready;

    cubicroot cubicroot_inst (
        .clk(clk),
        .rst(rst),
        .start(start),
        .x_in(x_in),
        .y_out(y_out),
        .ready(ready)
    );

    clock_gen cg_inst (
        .clk(clk)
    );

    initial begin
        rst = 1;
        start = 0;
        x_in = 16'd0;

        #40 rst = 0;
        $display("Cubic square test:");

        x_in = 16'd27;
        start = 1;
        #2 start = 0;

        wait (ready);
        $display("cubicroot(27) = %d", y_out);
        $finish;
    end
endmodule

// module mult_test;
//     wire clk;
//     reg rst;
//     reg start;
//     reg [15:0] a_in;
//     reg [15:0] b_in;
//     wire [15:0] f_out;
//     wire ready;

//     mult mult_inst (
//         .clk(clk),
//         .rst(rst),
//         .start(start),
//         .a_in(a_in),
//         .b_in(b_in),
//         .f_out(f_out),
//         .ready(ready)
//     );

//     clock_gen cg_inst (
//         .clk(clk)
//     );

//     integer i, j;

//     initial begin
//         rst = 1;
//         start = 0;
//         a_in = 16'd0;
//         b_in = 16'd0;

//         #20 rst = 0;
//         $display("Multiplier test:");

//         for (i = 0; i <= 12; i = i + 1) begin
//             for (j = 0; j <= 12; j = j + 1) begin
//                 #10;
//                 a_in = i;
//                 b_in = j;
//                 start = 1;
//                 #2 start = 0;

//                 wait (ready);
//                 $display("%d * %d = %d", i, j, f_out);
//             end
//         end

//         $display("-=-=-=-=-=-=-=-=-=");
//         $finish;
//     end
// endmodule