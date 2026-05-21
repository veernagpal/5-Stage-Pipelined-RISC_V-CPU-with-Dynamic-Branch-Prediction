module ALU_control(
    input [1:0] ALUOp_EX,
    input [2:0] funct3_EX,
    input [6:0] funct7_EX,
    output reg [3:0] ALU_select_EX
);

always @(*) begin
    case(ALUOp_EX)
        // load/store address calculation
        2'b00: begin
            ALU_select_EX = 4'b0000; // ADD
        end
        // R-type / I-type arithmetic instructions
        2'b10: begin
            case(funct3_EX)
                3'b000: begin
                    if(funct7_EX == 7'b0100000)
                        ALU_select_EX = 4'b0001; // SUB
                    else
                        ALU_select_EX = 4'b0000; // ADD
                end
                3'b111: begin
                    ALU_select_EX = 4'b0010; // AND
                end
                3'b110: begin
                    ALU_select_EX = 4'b0011; // OR
                end
                3'b010: begin
                    ALU_select_EX = 4'b0100; // SLT
                end
                default: begin
                    ALU_select_EX = 4'b0000;
                end
            endcase
        end
        default: begin
            ALU_select_EX = 4'b0000;
        end
    endcase
end
endmodule