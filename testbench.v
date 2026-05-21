





`timescale 1ns/1ps

module pipelined_CPU_tb;

reg clk;
reg reset;

TOP DUT(
    .clk(clk),
    .reset(reset)
);

// clock generation
always #5 clk = ~clk;

initial begin

    clk = 0;
    reset = 1;

    #20;
    reset = 0;

    #3000;

    $finish;

end

// waveform dump for GTKWave
initial begin

    $dumpfile("cpu.vcd");
    $dumpvars(0, pipelined_CPU_tb);

end

endmodule