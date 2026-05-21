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