
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