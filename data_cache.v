
module data_memory(

    input clk,

    input MemRead_MEM,
    input MemWrite_MEM,

    input [31:0] address_MEM,
    input [31:0] write_data_MEM,

    output reg [31:0] read_data_MEM

);
initial begin

    memory[0] = 32'd1;

end


reg [31:0] memory [0:255];

always @(*) begin

    if(MemRead_MEM)
        read_data_MEM = memory[address_MEM[31:2]];

    else
        read_data_MEM = 32'b0;

end

always @(posedge clk) begin

    if(MemWrite_MEM)
        memory[address_MEM[31:2]] <= write_data_MEM;

end

endmodule