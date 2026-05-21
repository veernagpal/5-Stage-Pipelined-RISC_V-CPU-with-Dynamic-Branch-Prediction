/*
TOP.v — 5-stage pipelined RISC-V processor
Stages: IF → ID → EX → MEM → WB
Features: forwarding, load-use hazard detection, 2-bit BHT + BTB branch predictor, branch resolution in ID, JAL/JALR support
Flush/Stall policy:
 - Load-use hazard   : stall PC + IF/ID, flush ID/EX (insert bubble)
 - Branch mispredict : flush IF/ID + ID/EX (2-cycle penalty)
 - JAL/JALR          : resolved in EX; flush IF/ID + ID/EX
 */

module TOP (
    input clk,
    input reset
);


//  IF stage wires

wire [31:0] pc_current;
wire [31:0] pc_plus4_IF;
wire [31:0] instn_IF;

wire predict_taken_IF;
wire [31:0] predicted_target_IF;
wire btb_hit_IF;


//  IF/ID pipeline register outputs
wire [31:0] pc_ID;
wire [31:0] instn_ID;
wire predict_taken_ID;
wire [31:0] predicted_target_ID;   // BTB target carried through IF/ID


//  ID stage wires
wire [6:0] opcode_ID  = instn_ID[6:0];
wire [4:0] rd_ID = instn_ID[11:7];
wire [2:0] funct3_ID  = instn_ID[14:12];
wire [4:0] rs1_ID = instn_ID[19:15];
wire [4:0] rs2_ID = instn_ID[24:20];
wire [6:0] funct7_ID = instn_ID[31:25];

wire [31:0] imm_ID;
wire [31:0] read_data1_raw_ID, read_data2_raw_ID;

// forwarded data for branch comparator
wire [1:0]  ForwardA_ID, ForwardB_ID;
wire [31:0] branch_rs1_ID, branch_rs2_ID;

// control signals from control unit
wire reg_write_ID, alu_src_ID, mem_read_ID, mem_write_ID;
wire mem_to_reg_ID, branch_ID, jump_ID;
wire [1:0]  ALUOp_ID;
wire jalr_ID = (opcode_ID == 7'b1100111); // JALR flag

// branch resolution
wire branch_taken_ID;
wire [31:0] branch_target_ID;


//  ID/EX pipeline register outputs
wire [31:0] pc_EX;
wire [31:0] read_data1_EX, read_data2_EX, imm_EX;
wire [4:0]  rs1_EX, rs2_EX, rd_EX;
wire [2:0]  funct3_EX;
wire [6:0]  funct7_EX, opcode_EX;
wire [1:0]  ALUOp_EX;
wire ALUSrc_EX, RegWrite_EX, MemRead_EX, MemWrite_EX, MemtoReg_EX;
wire Jump_EX, Jalr_EX;


//  EX stage wires
wire [1:0]  ForwardA_EX, ForwardB_EX;
wire [31:0] ALU_A, ALU_B_pre, ALU_B;
wire [3:0]  ALU_select_EX;
wire [31:0] ALU_result_EX;
wire [31:0] pc_plus4_EX;

// EX/MEM pipeline register outputs
wire [31:0] ALU_result_MEM;
wire [31:0] write_data_MEM;
wire [31:0] pc_plus4_MEM;
wire [4:0]  rd_MEM;
wire RegWrite_MEM, MemRead_MEM, MemWrite_MEM, MemtoReg_MEM, Jump_MEM;

//  MEM stage wires
wire [31:0] read_data_MEM_out;

// MEM/WB pipeline register outputs
wire [31:0] read_data_WB, ALU_result_WB, pc_plus4_WB;
wire [4:0]  rd_WB;
wire RegWrite_WB, MemtoReg_WB, Jump_WB;

//  WB stage
// write_data_WB: mem_data if MemtoReg, PC+4 if Jump, else ALU result
wire [31:0] write_data_WB;
assign write_data_WB = Jump_WB ? pc_plus4_WB : MemtoReg_WB ? read_data_WB : ALU_result_WB;

//  Hazard / flush control
wire stall_PC, stall_IF_ID, flush_ID_EX;


// predicted_target_ID is the BTB target carried through IF/ID for this branch.


wire branch_resolved = branch_ID && !stall_PC;

wire branch_mispredict = branch_resolved && (
    (branch_taken_ID != predict_taken_ID) ||
    (branch_taken_ID && (branch_target_ID != predicted_target_ID))
);

// JAL/JALR resolved in EX; flush 2 fetched instructions
wire jump_taken_EX = Jump_EX;

// Stall overrides flush: can't flush and stall simultaneously
wire flush_IF_ID_reg  = (branch_mispredict || jump_taken_EX) && !stall_PC;
wire flush_ID_EX_reg  = ((branch_mispredict || jump_taken_EX) && !stall_PC) || flush_ID_EX;



//  PC next-value selection
//  Priority:
//    1. JAL/JALR resolved in EX  → jump target
//    2. Branch misprediction      → correct target
//    3. Predict taken (BTB hit)   → predicted target
//    4. Default                   → PC+4


// JAL target: PC_EX + imm_EX ; JALR target: ALU result (rs1 + imm, [0] forced 0)
wire [31:0] jalr_target_EX = {ALU_result_EX[31:1], 1'b0};
wire [31:0] jal_target_EX  = pc_EX + imm_EX;
wire [31:0] jump_target_EX = Jalr_EX ? jalr_target_EX : jal_target_EX;

// Correct branch target (used on misprediction)
wire [31:0] branch_correct_target = branch_taken_ID ? branch_target_ID : pc_plus4_IF;

// We use pc_ID+4 as the fall-through when branch not taken
wire [31:0] branch_fallthrough = pc_ID + 32'd4;
wire [31:0] branch_resolved_pc = branch_taken_ID ? branch_target_ID : branch_fallthrough;

wire [31:0] pc_next;
assign pc_next = jump_taken_EX ? jump_target_EX : branch_mispredict ? branch_resolved_pc : (predict_taken_IF && btb_hit_IF) ? predicted_target_IF : pc_plus4_IF;


//  ALU forwarding muxes
// Forward for ALU A: 00=reg, 10=EX/MEM, 01=MEM/WB
assign ALU_A = (ForwardA_EX == 2'b10) ? ALU_result_MEM : (ForwardA_EX == 2'b01) ? write_data_WB  : read_data1_EX;

// Forward for ALU B (before src mux): 00=reg, 10=EX/MEM, 01=MEM/WB
assign ALU_B_pre = (ForwardB_EX == 2'b10) ? ALU_result_MEM : (ForwardB_EX == 2'b01) ? write_data_WB  : read_data2_EX;

// ALUSrc: 0=register, 1=immediate
assign ALU_B = ALUSrc_EX ? imm_EX : ALU_B_pre;

// For JAL, ALU computes PC+imm (already done combinatorially above);
// for JALR, ALU computes rs1+imm → use that as jump target.
// Both write PC+4 to rd via the Jump path in WB.

// PC+4 in EX stage (link address for JAL/JALR)
assign pc_plus4_EX = pc_EX + 32'd4;

// Branch comparator forwarding
assign branch_rs1_ID = (ForwardA_ID == 2'b10) ? ALU_result_MEM : (ForwardA_ID == 2'b01) ? write_data_WB  : read_data1_raw_ID;

assign branch_rs2_ID = (ForwardB_ID == 2'b10) ? ALU_result_MEM : (ForwardB_ID == 2'b01) ? write_data_WB  : read_data2_raw_ID;


//  Module instantiations

// PC register
pc PC (
    .clk(clk),
    .reset(reset),
    .stall(stall_PC),
    .pc_next(pc_next),
    .pc_current(pc_current)
);

// PC+4
pc_adder PC_ADD (
    .pc_current(pc_current),
    .pc_plus4(pc_plus4_IF)
);

// Instruction cache / ROM
instruction_cache ICACHE (
    .pc_current(pc_current),
    .instn_out(instn_IF)
);

// Branch predictor (2-bit BHT + BTB)
branch_predictor BP (
    .clk(clk),
    .reset(reset),
    .pc_IF(pc_current),
    .branch_valid_ID(branch_resolved),
    .pc_ID (pc_ID),
    .branch_taken_ID (branch_taken_ID),
    .branch_target_ID(branch_target_ID),
    .predict_taken_IF(predict_taken_IF),
    .predicted_target_IF(predicted_target_IF),
    .btb_hit_IF(btb_hit_IF)
);

// IF/ID pipeline register
IF_ID IFID (
    .clk (clk),
    .reset(reset),
    .flush(flush_IF_ID_reg),
    .stall(stall_IF_ID),
    .pc_IF(pc_current),
    .instn_IF(instn_IF),
    .predict_taken_IF (predict_taken_IF),
    .predicted_target_IF (predicted_target_IF),   // NEW: carry BTB target into ID
    .pc_ID (pc_ID),
    .instn_ID(instn_ID),
    .predict_taken_ID (predict_taken_ID),
    .predicted_target_ID (predicted_target_ID)    // NEW: used for mispredict check
);

// Control unit
control_unit CU (
    .opcode_ID (opcode_ID),
    .reg_write_ID (reg_write_ID),
    .alu_src_ID (alu_src_ID),
    .mem_read_ID(mem_read_ID),
    .mem_write_ID(mem_write_ID),
    .mem_to_reg_ID(mem_to_reg_ID),
    .branch_ID (branch_ID),
    .jump_ID (jump_ID),
    .ALUOp_ID (ALUOp_ID)
);

// Immediate generator
imm_gen IMMGEN (
    .instn_ID(instn_ID),
    .imm_ID (imm_ID)
);

// Register file
register_file RF (
    .clk (clk),
    .reset (reset),
    .rs1_ID (rs1_ID),
    .rs2_ID (rs2_ID),
    .reg_write_WB (RegWrite_WB),
    .rd_WB (rd_WB),
    .write_data_WB(write_data_WB),
    .read_data1_ID(read_data1_raw_ID),
    .read_data2_ID(read_data2_raw_ID)
);

// Branch resolution (in ID stage)
branch_resolution BR (
    .opcode_ID (opcode_ID),
    .funct3_ID (funct3_ID),
    .read_data1_ID (branch_rs1_ID),
    .read_data2_ID (branch_rs2_ID),
    .pc_ID (pc_ID),
    .imm_ID(imm_ID),
    .branch_taken_ID(branch_taken_ID),
    .branch_target_ID(branch_target_ID),
    .branch_resolved(branch_resolved)
);


// Hazard detection unit
hazard_detection_unit HDU (
    .clk (clk),             
    .reset (reset),            
    .MemRead_EX  (MemRead_EX),
    .RegWrite_EX (RegWrite_EX),      
    .rd_EX (rd_EX),
    .MemRead_MEM (MemRead_MEM),      
    .rd_MEM (rd_MEM),           
    .rs1_ID (rs1_ID),
    .rs2_ID (rs2_ID),
    .branch_ID (branch_ID),        
    .stall_PC (stall_PC),
    .stall_IF_ID (stall_IF_ID),
    .flush_ID_EX (flush_ID_EX)
);

// ID/EX pipeline register
ID_EX IDEX (
    .clk (clk),
    .reset (reset),
    .flush(flush_ID_EX_reg),
    .pc_ID (pc_ID),
    .read_data1_ID (read_data1_raw_ID),
    .read_data2_ID (read_data2_raw_ID),
    .imm_ID (imm_ID),
    .rs1_ID (rs1_ID),
    .rs2_ID (rs2_ID),
    .rd_ID (rd_ID),
    .funct3_ID (funct3_ID),
    .funct7_ID (funct7_ID),
    .opcode_ID (opcode_ID),
    .ALUOp_ID (ALUOp_ID),
    .ALUSrc_ID (alu_src_ID),
    .RegWrite_ID (reg_write_ID),
    .MemRead_ID (mem_read_ID),
    .MemWrite_ID (mem_write_ID),
    .MemtoReg_ID (mem_to_reg_ID),
    .Jump_ID (jump_ID),
    .Jalr_ID (jalr_ID),
    .pc_EX (pc_EX),
    .read_data1_EX (read_data1_EX),
    .read_data2_EX (read_data2_EX),
    .imm_EX(imm_EX),
    .rs1_EX (rs1_EX),
    .rs2_EX(rs2_EX),
    .rd_EX(rd_EX),
    .funct3_EX(funct3_EX),
    .funct7_EX(funct7_EX),
    .opcode_EX (opcode_EX),
    .ALUOp_EX (ALUOp_EX),
    .ALUSrc_EX (ALUSrc_EX),
    .RegWrite_EX(RegWrite_EX),
    .MemRead_EX (MemRead_EX),
    .MemWrite_EX (MemWrite_EX),
    .MemtoReg_EX (MemtoReg_EX),
    .Jump_EX (Jump_EX),
    .Jalr_EX (Jalr_EX)
);

// Forwarding unit
forwarding_unit FU (
    .rs1_EX (rs1_EX),
    .rs2_EX (rs2_EX),
    .rs1_ID (rs1_ID),
    .rs2_ID (rs2_ID),
    .rd_MEM (rd_MEM),
    .rd_WB (rd_WB),
    .RegWrite_MEM(RegWrite_MEM),
    .RegWrite_WB (RegWrite_WB),
    .ForwardA_EX (ForwardA_EX),
    .ForwardB_EX (ForwardB_EX),
    .ForwardA_ID (ForwardA_ID),
    .ForwardB_ID (ForwardB_ID)
);

// ALU control
ALU_control ALUCTRL (
    .ALUOp_EX (ALUOp_EX),
    .funct3_EX(funct3_EX),
    .funct7_EX(funct7_EX),
    .ALU_select_EX(ALU_select_EX)
);

// ALU
ALU ALU_INST (
    .A(ALU_A),
    .B(ALU_B),
    .ALU_select_EX (ALU_select_EX),
    .ALU_result_EX (ALU_result_EX)
);

// EX/MEM pipeline register
EX_MEM EXMEM (
    .clk(clk),
    .reset(reset),
    .flush(1'b0),           // no flush needed at EX/MEM boundary
    .ALU_result_EX (ALU_result_EX),
    .write_data_EX (ALU_B_pre),      // rs2 (forwarded) for store
    .pc_plus4_EX (pc_plus4_EX),
    .rd_EX (rd_EX),
    .RegWrite_EX (RegWrite_EX),
    .MemRead_EX (MemRead_EX),
    .MemWrite_EX(MemWrite_EX),
    .MemtoReg_EX(MemtoReg_EX),
    .Jump_EX (Jump_EX),
    .ALU_result_MEM(ALU_result_MEM),
    .write_data_MEM(write_data_MEM),
    .pc_plus4_MEM(pc_plus4_MEM),
    .rd_MEM (rd_MEM),
    .RegWrite_MEM (RegWrite_MEM),
    .MemRead_MEM (MemRead_MEM),
    .MemWrite_MEM(MemWrite_MEM),
    .MemtoReg_MEM(MemtoReg_MEM),
    .Jump_MEM(Jump_MEM)
);

// Data memory
data_memory DMEM (
    .clk (clk),
    .MemRead_MEM (MemRead_MEM),
    .MemWrite_MEM (MemWrite_MEM),
    .address_MEM(ALU_result_MEM),
    .write_data_MEM(write_data_MEM),
    .read_data_MEM(read_data_MEM_out)
);

// MEM/WB pipeline register
MEM_WB MEMWB (
    .clk (clk),
    .reset(reset),
    .flush (1'b0),
    .read_data_MEM(read_data_MEM_out),
    .ALU_result_MEM(ALU_result_MEM),
    .pc_plus4_MEM (pc_plus4_MEM),
    .rd_MEM (rd_MEM),
    .RegWrite_MEM (RegWrite_MEM),
    .MemtoReg_MEM (MemtoReg_MEM),
    .Jump_MEM (Jump_MEM),
    .read_data_WB (read_data_WB),
    .ALU_result_WB(ALU_result_WB),
    .pc_plus4_WB  (pc_plus4_WB),
    .rd_WB (rd_WB),
    .RegWrite_WB  (RegWrite_WB),
    .MemtoReg_WB  (MemtoReg_WB),
    .Jump_WB (Jump_WB)
);

// WB writeback mux is a simple assign at the top of this file (write_data_WB)

endmodule

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

module pc_adder(pc_current,pc_plus4);
input [31:0] pc_current;
output [31:0] pc_plus4;

assign pc_plus4 = pc_current + 32'd4;

endmodule

module instruction_cache(pc_current,instn_out);

input [31:0] pc_current;
output [31:0] instn_out;

reg [7:0] icache [0:1023]; // 1KB byte addressed memory

// ROM based hardwired instructions
initial begin

// addi x1, x0, 5      addr=0
icache[0]=8'h93; icache[1]=8'h00; icache[2]=8'h50; icache[3]=8'h00;
// jal  x10, +8        addr=4    → target=12, x10=8
icache[4]=8'h6F; icache[5]=8'h05; icache[6]=8'h80; icache[7]=8'h00;
// addi x2, x0, 99     addr=8    SKIPPED by jal
icache[8]=8'h13; icache[9]=8'h01; icache[10]=8'h30; icache[11]=8'h06;
// addi x3, x0, 42     addr=12   jal lands here
icache[12]=8'h93; icache[13]=8'h01; icache[14]=8'hA0; icache[15]=8'h02;
// addi x10, x0, 28    addr=16   set up jalr target
icache[16]=8'h13; icache[17]=8'h05; icache[18]=8'hC0; icache[19]=8'h01;
// jalr x11, x10, 0    addr=20   → target=28, x11=24
icache[20]=8'hE7; icache[21]=8'h05; icache[22]=8'h05; icache[23]=8'h00;
// addi x4, x0, 99     addr=24   SKIPPED by jalr
icache[24]=8'h13; icache[25]=8'h02; icache[26]=8'h30; icache[27]=8'h06;
// addi x5, x0, 77     addr=28   jalr lands here
icache[28]=8'h93; icache[29]=8'h02; icache[30]=8'hD0; icache[31]=8'h04;

end

assign instn_out = {icache[pc_current+3],icache[pc_current+2],icache[pc_current+1],icache[pc_current]}; //little endian format

endmodule


module register_file(clk,reset,rs1_ID,rs2_ID,reg_write_WB,rd_WB,write_data_WB,read_data1_ID,read_data2_ID);
input clk,reset,reg_write_WB;
input [4:0] rs1_ID,rs2_ID,rd_WB;
input [31:0] write_data_WB;
output [31:0] read_data1_ID,read_data2_ID;

reg [31:0] registers [0:31]; // 32 x 32 register file

integer i;

// write operation
always @ (posedge clk) begin
    if(reset) begin
        for (i = 0; i<32; i=i+1) begin
            registers[i] <= 32'd0;
        end
    end

    else if (reg_write_WB && (rd_WB != 0)) begin
        registers[rd_WB] <= write_data_WB;
    end
end


initial begin
    registers[0] = 0;
    registers[1] = 0;

end
// Read operation
assign read_data1_ID =
    (reg_write_WB && (rd_WB != 0) && (rd_WB == rs1_ID))
        ? write_data_WB
        : registers[rs1_ID];

assign read_data2_ID =
    (reg_write_WB && (rd_WB != 0) && (rd_WB == rs2_ID))
        ? write_data_WB
        : registers[rs2_ID];

// WB stage forwarding added as well as i could not implement writes in the first half and reads in the second half of the clock cycle, hence this is implemented for simulation purposes...

endmodule


module mux2_1(select,i0,i1,out);
input [31:0] i0,i1;
output reg [31:0] out;
input select;

always @ (*) begin
    if(select)
        out = i1;
    else 
        out = i0;
end
endmodule



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



module branch_predictor(
    input clk,
    input reset,
    input [31:0] pc_IF,
    input branch_valid_ID,
    input [31:0] pc_ID,
    input branch_taken_ID,
    input [31:0] branch_target_ID,
    output predict_taken_IF,
    output [31:0] predicted_target_IF,
    output btb_hit_IF
);

reg [1:0] bht [0:15];
reg [31:0] btb_target [0:15];
reg btb_valid [0:15];

integer i;

wire [3:0] index_IF;
wire [3:0] index_ID;

assign index_IF = pc_IF[5:2];

assign index_ID = pc_ID[5:2];

assign predict_taken_IF = bht[index_IF][1];

assign predicted_target_IF = btb_target[index_IF];

assign btb_hit_IF = btb_valid[index_IF];

always @(posedge clk) begin

    if(reset) begin
        for(i = 0; i < 16; i = i + 1) begin

            bht[i] <= 2'b01;

            btb_target[i] <= 32'b0;

            btb_valid[i] <= 1'b0;

        end

    end

    else if(branch_valid_ID) begin

        if(branch_taken_ID) begin

            if(bht[index_ID] != 2'b11)
                bht[index_ID] <= bht[index_ID] + 1;

            btb_target[index_ID] <= branch_target_ID;

            btb_valid[index_ID] <= 1'b1;

        end

        else begin

            if(bht[index_ID] != 2'b00)
                bht[index_ID] <= bht[index_ID] - 1;
        end
    end
end
endmodule




module IF_ID(
    input clk, reset, flush, stall,
    input [31:0]  pc_IF,
    input [31:0]  instn_IF,
    input         predict_taken_IF,
    input [31:0]  predicted_target_IF,   // carry BTB target through
    output reg [31:0] pc_ID,
    output reg [31:0] instn_ID,
    output reg        predict_taken_ID,
    output reg [31:0] predicted_target_ID // used for mispredict check in TOP
);
 
always @(posedge clk) begin
    if (flush | reset) begin
        pc_ID               <= 32'b0;
        instn_ID            <= 32'h00000013; // NOP
        predict_taken_ID    <= 1'b0;
        predicted_target_ID <= 32'b0;
    end
    else if (stall) begin
        pc_ID               <= pc_ID;
        instn_ID            <= instn_ID;
        predict_taken_ID    <= predict_taken_ID;
        predicted_target_ID <= predicted_target_ID;
    end
    else begin
        pc_ID               <= pc_IF;
        instn_ID            <= instn_IF;
        predict_taken_ID    <= predict_taken_IF;
        predicted_target_ID <= predicted_target_IF;
    end
end
 
endmodule

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

module hazard_detection_unit(
    input clk,
    input reset,

    // EX stage
    input        MemRead_EX,
    input        RegWrite_EX,
    input [4:0]  rd_EX,

    // MEM stage
    input        MemRead_MEM,
    input [4:0]  rd_MEM,

    // ID stage
    input [4:0]  rs1_ID,
    input [4:0]  rs2_ID,
    input        branch_ID,      // branch instruction currently in ID

    // control outputs
    output reg   stall_PC,
    output reg   stall_IF_ID,
    output reg   flush_ID_EX

);

    // tracks remaining stall cycles for the 2-stall case
    reg [1:0] stall_counter;

    // combinational match helpers
    wire rs1_match_EX  = (rd_EX  != 5'b0) && (rd_EX  == rs1_ID);
    wire rs2_match_EX  = (rd_EX  != 5'b0) && (rd_EX  == rs2_ID);
    wire rs1_match_MEM = (rd_MEM != 5'b0) && (rd_MEM == rs1_ID);
    wire rs2_match_MEM = (rd_MEM != 5'b0) && (rd_MEM == rs2_ID);

    wire ex_hits_branch  = branch_ID && (rs1_match_EX  || rs2_match_EX);
    wire mem_hits_branch = branch_ID && (rs1_match_MEM || rs2_match_MEM);

    // stall counter: loaded with 1 when 2-stall sequence begins
    always @(posedge clk) begin
        if (reset)
            stall_counter <= 2'd0;
        else if (MemRead_EX && ex_hits_branch)
            stall_counter <= 2'd1;
        else if (stall_counter != 2'd0)
            stall_counter <= stall_counter - 2'd1;
    end

    always @(*) begin
        stall_PC    = 1'b0;
        stall_IF_ID = 1'b0;
        flush_ID_EX = 1'b0;

        // load-use hazard, non-branch consumer
        if (MemRead_EX && !branch_ID &&
            (rs1_match_EX || rs2_match_EX)) begin
            stall_PC    = 1'b1;
            stall_IF_ID = 1'b1;
            flush_ID_EX = 1'b1;
        end

        // Case 1: non-load in EX, branch in ID — 1 stall
        else if (RegWrite_EX && !MemRead_EX && ex_hits_branch) begin
            stall_PC    = 1'b1;
            stall_IF_ID = 1'b1;
            flush_ID_EX = 1'b1;
        end

        // Case 2: load in EX, branch in ID — stall cycle 1 of 2
        else if (MemRead_EX && ex_hits_branch) begin
            stall_PC    = 1'b1;
            stall_IF_ID = 1'b1;
            flush_ID_EX = 1'b1;
        end

        // Case 2 cont: stall cycle 2 of 2 (counter still live)
        else if (stall_counter != 2'd0) begin
            stall_PC    = 1'b1;
            stall_IF_ID = 1'b1;
            flush_ID_EX = 1'b1;
        end

        // Case 3: load in MEM, branch in ID — 1 stall
        else if (MemRead_MEM && mem_hits_branch) begin
            stall_PC    = 1'b1;
            stall_IF_ID = 1'b1;
            flush_ID_EX = 1'b1;
        end
    end

endmodule

module forwarding_unit(

    // EX stage source registers
    input [4:0] rs1_EX,
    input [4:0] rs2_EX,

    // ID stage source registers (for branch resolution)
    input [4:0] rs1_ID,
    input [4:0] rs2_ID,

    // branch indicator
    input branch_ID,

    // destination registers from later stages
    input [4:0] rd_MEM,
    input [4:0] rd_WB,

    // control signals
    input RegWrite_MEM,
    input RegWrite_WB,

    // forwarding controls for ALU inputs
    output reg [1:0] ForwardA_EX,
    output reg [1:0] ForwardB_EX,

    // forwarding controls for branch comparator in ID
    output reg [1:0] ForwardA_ID,
    output reg [1:0] ForwardB_ID

);

always @(*) begin

    // defaults
    ForwardA_EX = 2'b00;
    ForwardB_EX = 2'b00;

    // rs1_EX forwarding
    if (RegWrite_MEM && (rd_MEM != 0) && (rd_MEM == rs1_EX))
        ForwardA_EX = 2'b10;

    if (RegWrite_WB && (rd_WB != 0) && (rd_WB == rs1_EX) && !(RegWrite_MEM && (rd_MEM != 0) && (rd_MEM == rs1_EX)))
        ForwardA_EX = 2'b01;


    // rs2_EX forwarding
    if (RegWrite_MEM && (rd_MEM != 0) && (rd_MEM == rs2_EX))
        ForwardB_EX = 2'b10;

    if (RegWrite_WB && (rd_WB != 0) && (rd_WB == rs2_EX) && !(RegWrite_MEM && (rd_MEM != 0) && (rd_MEM == rs2_EX)))
        ForwardB_EX = 2'b01;
end 

always @ (*) begin

    
    ForwardA_ID = 2'b00;
    ForwardB_ID = 2'b00;

    // ID forwarding only for branch instructions
    

        // rs1_ID forwarding
        if (RegWrite_MEM && (rd_MEM != 0) && (rd_MEM == rs1_ID))
            ForwardA_ID = 2'b10;

        if (RegWrite_WB && (rd_WB != 0) && (rd_WB == rs1_ID) && !(RegWrite_MEM && (rd_MEM != 0) && (rd_MEM == rs1_ID)))
            ForwardA_ID = 2'b01;


        // rs2_ID forwarding
        if (RegWrite_MEM && (rd_MEM != 0) && (rd_MEM == rs2_ID))
            ForwardB_ID = 2'b10;

        if (RegWrite_WB && (rd_WB != 0) && (rd_WB == rs2_ID) && !(RegWrite_MEM && (rd_MEM != 0) && (rd_MEM == rs2_ID)))
            ForwardB_ID = 2'b01;

    

end

endmodule

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








`timescale 1ns/1ps

module pipelined_CPU_tb;

reg clk;
reg reset;

TOP DUT(
    .clk(clk),
    .reset(reset)
);

// clock generation
always #5 clk = ~clk;

initial begin

    clk = 0;
    reset = 1;

    #20;
    reset = 0;

    #3000;

    $finish;

end

// waveform dump for GTKWave
initial begin

    $dumpfile("cpu.vcd");
    $dumpvars(0, pipelined_CPU_tb);

end

endmodule
