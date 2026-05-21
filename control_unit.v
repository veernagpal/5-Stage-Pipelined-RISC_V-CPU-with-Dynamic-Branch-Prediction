module control_unit(opcode_ID, reg_write_ID, alu_src_ID, mem_read_ID, mem_write_ID, mem_to_reg_ID, branch_ID, jump_ID, ALUOp_ID);

input [6:0] opcode_ID ;

output reg reg_write_ID, alu_src_ID, mem_read_ID, mem_write_ID, mem_to_reg_ID, branch_ID, jump_ID ;
output reg [1:0] ALUOp_ID ;

always @ (*) begin
   reg_write_ID = 0; 
   alu_src_ID = 0;
   mem_read_ID = 0;
   mem_write_ID = 0;
   mem_to_reg_ID = 0;
   branch_ID = 0;
   jump_ID = 0;
   ALUOp_ID = 2'b00;
   //to avoid inferrred latches

   case(opcode_ID)
    //R type
    7'b0110011: begin
        reg_write_ID = 1; 
        alu_src_ID = 0;
        mem_read_ID = 0;
        mem_write_ID = 0;
        mem_to_reg_ID = 0;
        branch_ID = 0;
        jump_ID = 0;
        ALUOp_ID = 2'b10;
    end

    //I type ALU
    7'b0010011: begin
        reg_write_ID = 1; 
        alu_src_ID = 1;
        mem_read_ID = 0;
        mem_write_ID = 0;
        mem_to_reg_ID = 0;
        branch_ID = 0;
        jump_ID = 0;
        ALUOp_ID = 2'b10;
    end

    // load - lw
    7'b0000011: begin
        reg_write_ID = 1; 
        alu_src_ID = 1;
        mem_read_ID = 1;
        mem_write_ID = 0;
        mem_to_reg_ID = 1;
        branch_ID = 0;
        jump_ID = 0;
        ALUOp_ID = 2'b00;
    end

    //store - sw
    7'b0100011: begin
        reg_write_ID = 0; 
        alu_src_ID = 1;
        mem_read_ID = 0;
        mem_write_ID = 1;
        mem_to_reg_ID = 0;
        branch_ID = 0;
        jump_ID = 0;
        ALUOp_ID = 2'b00;
    end

    // branch
    7'b1100011: begin
        reg_write_ID = 0; 
        alu_src_ID = 0;
        mem_read_ID = 0;
        mem_write_ID = 0;
        mem_to_reg_ID = 0;
        branch_ID = 1;
        jump_ID = 0;
        ALUOp_ID = 2'b01;
    end

    // jal
    7'b1101111: begin
        reg_write_ID = 1; 
        alu_src_ID = 0;
        mem_read_ID = 0;
        mem_write_ID = 0;
        mem_to_reg_ID = 0;
        branch_ID = 0;
        jump_ID = 1;
        ALUOp_ID = 2'b00;
    end

    // jalr
    7'b1100111: begin
        reg_write_ID = 1; 
        alu_src_ID = 1;
        mem_read_ID = 0;
        mem_write_ID = 0;
        mem_to_reg_ID = 0;
        branch_ID = 0;
        jump_ID = 1;
        ALUOp_ID = 2'b00;
    end

    default: begin
        reg_write_ID = 0; 
        alu_src_ID = 0;
        mem_read_ID = 0;
        mem_write_ID = 0;
        mem_to_reg_ID = 0;
        branch_ID = 0;
        jump_ID = 0;
        ALUOp_ID = 2'b00;
    end

   endcase
end

endmodule
