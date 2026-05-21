
module branch_resolution(
    input  [6:0]  opcode_ID,
    input  [2:0]  funct3_ID,
    input  [31:0] read_data1_ID,
    input  [31:0] read_data2_ID,
    input  [31:0] pc_ID,
    input  [31:0] imm_ID,
    output reg    branch_taken_ID,
    output [31:0] branch_target_ID,
    input branch_resolved
);
 
assign branch_target_ID = pc_ID + imm_ID;
 
always @(*) begin
    branch_taken_ID = 1'b0;
    if ((opcode_ID == 7'b1100011) & branch_resolved) begin
        case (funct3_ID)
            3'b000: branch_taken_ID = (read_data1_ID == read_data2_ID);         // beq
            3'b001: branch_taken_ID = (read_data1_ID != read_data2_ID);         // bne
            3'b100: branch_taken_ID = ($signed(read_data1_ID) < $signed(read_data2_ID));  // blt
            3'b101: branch_taken_ID = ($signed(read_data1_ID) >= $signed(read_data2_ID)); // bge
            default: branch_taken_ID = 1'b0;
        endcase
    end
end
 
endmodule