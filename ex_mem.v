module EX_MEM(
    input clk, reset, flush,

    input [31:0] ALU_result_EX,
    input [31:0] write_data_EX,
    input [31:0] pc_plus4_EX,   // PC+4 for JAL/JALR link write
    input [4:0]  rd_EX,

    input RegWrite_EX, MemRead_EX, MemWrite_EX, MemtoReg_EX,
    input Jump_EX,

    output reg [31:0] ALU_result_MEM,
    output reg [31:0] write_data_MEM,
    output reg [31:0] pc_plus4_MEM,
    output reg [4:0]  rd_MEM,

    output reg RegWrite_MEM, MemRead_MEM, MemWrite_MEM, MemtoReg_MEM,
    output reg Jump_MEM
);

always @(posedge clk) begin
    if (reset || flush) begin
        ALU_result_MEM <= 32'b0;
        write_data_MEM <= 32'b0;
        pc_plus4_MEM   <= 32'b0;
        rd_MEM         <= 5'b0;
        RegWrite_MEM   <= 1'b0;
        MemRead_MEM    <= 1'b0;
        MemWrite_MEM   <= 1'b0;
        MemtoReg_MEM   <= 1'b0;
        Jump_MEM       <= 1'b0;
    end else begin
        ALU_result_MEM <= ALU_result_EX;
        write_data_MEM <= write_data_EX;
        pc_plus4_MEM   <= pc_plus4_EX;
        rd_MEM         <= rd_EX;
        RegWrite_MEM   <= RegWrite_EX;
        MemRead_MEM    <= MemRead_EX;
        MemWrite_MEM   <= MemWrite_EX;
        MemtoReg_MEM   <= MemtoReg_EX;
        Jump_MEM       <= Jump_EX;
    end
end

endmodule
