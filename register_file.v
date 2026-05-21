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
