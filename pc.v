module pc(
    input  [31:0] pc_next,
    output reg [31:0] pc_current,
    input clk, stall, reset
);
 
always @(posedge clk) begin
    if (reset)
        pc_current <= 32'b0;
    else if (!stall)
        pc_current <= pc_next;
end
endmodule