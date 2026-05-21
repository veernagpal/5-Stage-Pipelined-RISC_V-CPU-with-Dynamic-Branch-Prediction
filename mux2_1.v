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


