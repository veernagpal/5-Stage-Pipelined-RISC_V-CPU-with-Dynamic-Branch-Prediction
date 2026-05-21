module imm_gen(
    input [31:0] instn_ID,
    output reg [31:0] imm_ID
);

wire [6:0] opcode_ID;

assign opcode_ID = instn_ID[6:0];

always @(*) begin

    case(opcode_ID)

        // I-type
        7'b0010011, // addi, andi, ori, slti
        7'b0000011, // lw
        7'b1100111: // jalr
        begin
            imm_ID = {{20{instn_ID[31]}}, instn_ID[31:20]};
        end

        // S-type
        7'b0100011: begin // sw
            imm_ID = {{20{instn_ID[31]}},
                      instn_ID[31:25],
                      instn_ID[11:7]};
        end

        // B-type
        7'b1100011: begin // beq, bne, blt, bge
            imm_ID = {{19{instn_ID[31]}},
                      instn_ID[31],
                      instn_ID[7],
                      instn_ID[30:25],
                      instn_ID[11:8],
                      1'b0};
        end

        // J-type
        7'b1101111: begin // jal
            imm_ID = {{11{instn_ID[31]}},
                      instn_ID[31],
                      instn_ID[19:12],
                      instn_ID[20],
                      instn_ID[30:21],
                      1'b0};
        end

        default: begin
            imm_ID = 32'b0;
        end

    endcase

end

endmodule