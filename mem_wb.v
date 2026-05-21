module MEM_WB(
    input clk, reset, flush,

    input [31:0] read_data_MEM,
    input [31:0] ALU_result_MEM, 
    input [31:0] pc_plus4_MEM,
    input [4:0]  rd_MEM,

    input RegWrite_MEM, MemtoReg_MEM,
    input Jump_MEM,

    output reg [31:0] read_data_WB,
    output reg [31:0] ALU_result_WB,
    output reg [31:0] pc_plus4_WB,
    output reg [4:0]  rd_WB,

    output reg RegWrite_WB, MemtoReg_WB,
    output reg Jump_WB
);

always @(posedge clk) begin
    if (reset || flush) begin
        read_data_WB  <= 32'b0;
        ALU_result_WB <= 32'b0;
        pc_plus4_WB   <= 32'b0;
        rd_WB         <= 5'b0;
        RegWrite_WB   <= 1'b0;
        MemtoReg_WB   <= 1'b0;
        Jump_WB       <= 1'b0;
    end else begin
        read_data_WB  <= read_data_MEM;
        ALU_result_WB <= ALU_result_MEM;
        pc_plus4_WB   <= pc_plus4_MEM;
        rd_WB         <= rd_MEM;
        RegWrite_WB   <= RegWrite_MEM;
        MemtoReg_WB   <= MemtoReg_MEM;
        Jump_WB       <= Jump_MEM;
    end
end

endmodule
