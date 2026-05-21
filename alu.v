
module ALU(
    input [31:0] A,
    input [31:0] B,
    input [3:0] ALU_select_EX,
    output reg [31:0] ALU_result_EX
);

always @(*) begin

    case(ALU_select_EX)

        4'b0000: ALU_result_EX = A + B; // ADD
        4'b0001: ALU_result_EX = A - B; // SUB
        4'b0010: ALU_result_EX = A & B; // AND
        4'b0011: ALU_result_EX = A | B; // OR
        4'b0100: ALU_result_EX = (A < B) ? 32'b1 : 32'b0; // SLT

        default: ALU_result_EX = 32'b0;

    endcase

end

endmodule
