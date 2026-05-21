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