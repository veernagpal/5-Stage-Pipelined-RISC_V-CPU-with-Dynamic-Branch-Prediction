module ID_EX(
    input clk, reset, flush,

    // data signals
    input [31:0] pc_ID,
    input [31:0] read_data1_ID,
    input [31:0] read_data2_ID,
    input [31:0] imm_ID,

    // register fields
    input [4:0] rs1_ID, rs2_ID, rd_ID,

    // instruction fields
    input [2:0] funct3_ID,
    input [6:0] funct7_ID,
    input [6:0] opcode_ID,

    // control signals
    input [1:0] ALUOp_ID,
    input ALUSrc_ID, RegWrite_ID, MemRead_ID, MemWrite_ID, MemtoReg_ID,
    input Jump_ID,   // JAL or JALR
    input Jalr_ID,   // JALR specifically (use rs1 as base)

    // outputs to EX stage
    output reg [31:0] pc_EX,
    output reg [31:0] read_data1_EX,
    output reg [31:0] read_data2_EX,
    output reg [31:0] imm_EX,
    output reg [4:0]  rs1_EX, rs2_EX, rd_EX,
    output reg [2:0]  funct3_EX,
    output reg [6:0]  funct7_EX,
    output reg [6:0]  opcode_EX,

    output reg [1:0] ALUOp_EX,
    output reg ALUSrc_EX, RegWrite_EX, MemRead_EX, MemWrite_EX, MemtoReg_EX,
    output reg Jump_EX,
    output reg Jalr_EX
);

always @(posedge clk) begin
    if (reset || flush) begin
        pc_EX         <= 32'b0;
        read_data1_EX <= 32'b0;
        read_data2_EX <= 32'b0;
        imm_EX        <= 32'b0;
        rs1_EX        <= 5'b0;
        rs2_EX        <= 5'b0;
        rd_EX         <= 5'b0;
        funct3_EX     <= 3'b0;
        funct7_EX     <= 7'b0;
        opcode_EX     <= 7'b0;
        ALUOp_EX      <= 2'b0;
        ALUSrc_EX     <= 1'b0;
        RegWrite_EX   <= 1'b0;
        MemRead_EX    <= 1'b0;
        MemWrite_EX   <= 1'b0;
        MemtoReg_EX   <= 1'b0;
        Jump_EX       <= 1'b0;
        Jalr_EX       <= 1'b0;
    end else begin
        pc_EX         <= pc_ID;
        read_data1_EX <= read_data1_ID;
        read_data2_EX <= read_data2_ID;
        imm_EX        <= imm_ID;
        rs1_EX        <= rs1_ID;
        rs2_EX        <= rs2_ID;
        rd_EX         <= rd_ID;
        funct3_EX     <= funct3_ID;
        funct7_EX     <= funct7_ID;
        opcode_EX     <= opcode_ID;
        ALUOp_EX      <= ALUOp_ID;
        ALUSrc_EX     <= ALUSrc_ID;
        RegWrite_EX   <= RegWrite_ID;
        MemRead_EX    <= MemRead_ID;
        MemWrite_EX   <= MemWrite_ID;
        MemtoReg_EX   <= MemtoReg_ID;
        Jump_EX       <= Jump_ID;
        Jalr_EX       <= Jalr_ID;
    end
end

endmodule