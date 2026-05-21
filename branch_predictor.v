
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