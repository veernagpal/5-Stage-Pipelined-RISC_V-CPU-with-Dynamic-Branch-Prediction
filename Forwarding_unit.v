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

    //end

end

endmodule