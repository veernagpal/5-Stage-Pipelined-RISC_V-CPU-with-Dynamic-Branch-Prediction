# 5-Stage-Pipelined-RISC_V-CPU-with-Dynamic-Branch-Prediction

A Verilog implementation of a 32-bit 5-stage RV32I pipelined processor featuring forwarding, hazard detection, ID-stage branch resolution, speculative instruction fetch, a dynamic 2-bit branch predictor, and BTB-based branch target prediction.
The primary focus of this project is efficient control hazard mitigation using dynamic branch prediction and speculative execution — especially for loop-heavy workloads.

PRIMARY FEATURES: 

Module overview :

TOP.v — Top-level integration module connecting all five pipeline stages, forwarding paths, hazard detection logic, branch resolution logic, branch predictor, and PC control/redirect logic

pc.v — Program Counter (PC) register with stall support and synchronous update logic

pc_adder.v — Combinational PC incrementer used to generate PC + 4

instruction_cache.v — Byte-addressed 1KB instruction memory used during instruction fetch

IF_ID.v — IF/ID pipeline register carrying fetched instruction, PC, branch prediction bits, and BTB target information

control_unit.v — Main instruction decoder generating datapath and pipeline control signals from opcode fields

immgen.v — Immediate generator supporting I-type, S-type, B-type, and J-type RISC-V instruction formats

register_file.v — 32 × 32-bit register file with same-cycle WB-stage forwarding support for simultaneous read/write access

branch_resolution.v — ID-stage branch comparator and target generation unit used for branch resolution and misprediction detection

branch_predictor.v — Dynamic branch prediction unit implementing a 2-bit BHT and BTB with full-PC tag matching

hazard_detection.v — Detects load-use hazards and branch RAW hazards, generating stall, bubble, and flush control signals

forwarding_unit.v — Generates forwarding select signals for both EX-stage ALU operands and ID-stage branch comparator operands

ID_EX.v — ID/EX pipeline register carrying decoded operands, immediates, and control signals into the EX stage

ALU_control.v — Generates ALU operation select signals using ALUOp, funct3, and funct7 fields

ALU.v — 32-bit Arithmetic Logic Unit supporting operations such as ADD, SUB, AND, OR, and SLT

EX_MEM.v — EX/MEM pipeline register carrying ALU results, store data, control signals, and PC + 4 for jump link instructions

data_cache.v — 32-bit word-addressed data memory used for load and store operations

MEM_WB.v — MEM/WB pipeline register carrying memory/ALU results and write-back control signals

The Pipeline Architecture : Classic 5-stage RV32I pipeline consisting of IF(Instruction Fetch),ID(Instruction Decode),EX(Execute), MEM(Memory Access),WB (Write Back)

Hazard Handling (primarily RAW hazards) : done by EX-stage forwarding , ID-stage branch forwarding (as branch resolution is done in the ID stage) , Load-use hazard detection and appropriate stalling (1 cycle) and Load-to-branch RAW hazard detection and appropriate stalling (2 cycles)

Branch Handling : The Branch resolution happens in ID stage, A Dynamic 2-bit branch predictor along with a Branch Target Buffer (BTB) facilitates Speculative instruction fetch, on a Branch Misprediction a recovery mechanism is in place of flushing the wrongly fetched instructions. The dynamic 2-bit branch predictor greatly helps in improving the performance of the CPU in loop heavy workloads.

Significance of the Branch Predictor : Branches are one of the biggest performance bottlenecks in pipelined processors. When the CPU fetches a branch instruction, it does not yet know whether the branch will actually be taken or not. The branch only gets resolved later in the pipeline after the branch comparator runs.
While the CPU is waiting for the decision of branch resolution : it continues fetching instructions, speculating on the future control flow.
If the speculation was wrong: the fetched instructions are useless, the pipeline must flush them, the PC must be redirected, and cycles are wasted.

This penalty becomes especially severe in loops.

Without a branch predictor ; the CPU follows a very simple policy: it always assumes that branches are not taken and continues fetching instructions sequentially. This works fine for branches that are actually not taken, but whenever a branch turns out to be taken, the CPU has already fetched the wrong instruction. As a result, the incorrectly fetched instruction must be flushed from the pipeline, and the Program Counter (PC) must be redirected to the correct branch target address. This creates a branch penalty every single time a taken branch occurs, leading to significant performance loss in loop-heavy programs where branches are repeatedly taken.

Consider the follwoing Example which demonstrates Loop Execution Without and With Prediction :

Consider a loop, assume the loop executes 1000 times.:

loop:
addi x1,x1,-1
bne  x1,x0,loop

The branch behavior is:
T T T T T T ... T NT

Without branch prediction:
every taken branch is mispredicted, every taken branch causes a flush, every taken branch wastes cycles.
For a 1000-iteration loop: 999 branch mispredictions occur, massive performance loss, constant pipeline disruption

The processor spends a large amount of time recovering from control hazards instead of doing useful work.

With a Dynamic 2-Bit Branch Predictor + BTB : 
Together, the Predictor and the BTB allow the CPU to ; learn branch behavior over time, speculatively fetch future instructions, and dramatically reduce loop-related control hazard penalties.

Each branch has an associated 2-bit state in the Branch History Table (BHT).

State	     Prediction
  00	  Strongly Not Taken
  01	  Weakly Not Taken
  10	    Weakly Taken
  11	   Strongly Taken

The predictor changes state gradually instead of immediately flipping prediction after a single branch outcome, This makes the predictor highly effective for repetitive loop branches.

Effectiveness of the Predictor in loop heavy workload:
Loops typically behave like this:

T T T T T ... T NT
The branch is: taken repeatedly, and only becomes not-taken once when the loop exits. The predictor learns this pattern very quickly.

Considering a standard loop execution :
Iteration 1 (Loop Entry): The CPU has never seen this branch before, BTB miss, predictor defaults on start is (weakly) NOT taken, but the branch is actually TAKEN, thus misprediction occurs, pipeline flushes, predictor updates state, BTB now stores target address for future use.
Iteration 2: The predictor has now learned the branch behavior (moves to weakly taken state). predictor says TAKEN, BTB immediately provides target PC, speculative fetch redirects correctly, no flush occurs.
Iterations 3, 4, 5...and so on : The predictor becomes strongly trained, branch prediction remains correct, speculative fetch continues smoothly ,pipeline stays full and free of and control hazard stalls as no control hazard penalty occurs.
Final Iteration (Loop Exit) : The branch finally becomes NOT taken. But the predictor still expects TAKEN. Hence a branch mispredict occurs here and the wrongly fetched instructions need to be flushed.

The crux : No matter how many times the loop executes, only TWO mispredictions occur the Initial cold-start misprediction and the Final loop-exit misprediction.
This is the key architectural advantage of dynamic branch prediction.

Loop Iterations	         No Predictor	                  2-bit Predictor
        5	               4 mispredicts                   2 mispredicts
       100	             99 mispredicts	                 2 mispredicts
       1000	            999 mispredicts	                 2 mispredicts

The control hazard penalty changes from: O(N) to O(1) for loops, which means: regardless of loop length, the predictor incurs only a fixed branch penalty. This dramatically improves performance for loop-heavy programs.

Significance of the BTB : In the case the 2 bit predictor predicts a branch to be taken then, The predictor tells the CPU - The branch will be taken. For this 
the CPU needs to know WHERE to jump and it needs this information immediately during instruction fetch. This is where the Branch Target Buffer (BTB) comes in.
The BTB stores: branch PC(i.e the address of the branch instruction) and corresponding target address. So when the fetch stage encounters a known branch:
the target address is available instantly, without waiting for decode or immediate generation. This eliminates additional branch redirection latency.

Speculative Execution and Recovery : The processor performs speculative instruction fetch based on branch predictions. If the prediction is correct then
execution proceeds as normal and no pipeline penalty occurs. If the prediction is wrong then the  incorrectly fetched instructions are flushed,
PC is redirected, predictor state updates, and execution recovers correctly. 

One of the major design choices in this CPU is to resolve branches in the ID stage. This reduces branch penalty compared to later branch resolution.
Thus in the decode stage the following is implemented: branch comparison, branch outcome evaluation, misprediction detection, and redirect generation.
To support this efficiently: ID-stage forwarding paths are implemented, allowing branch operands to be forwarded directly into the branch comparator.
This reduces unnecessary stalls for branch instructions.

Hazard Handling & Data Forwarding : The CPU includes extensive hazard mitigation logic and Data forwarding to prevent performance dip due to RAW hazards.

EX-stage Forwarding : Arithmetic RAW hazards are reduced using forwarding paths from MEM stage or WB stage
ID-stage Branch Forwarding : Branch instructions require operand comparison in the ID stage. To avoid waiting for write-back branch operands are forwarded directly into the branch comparator. This allows faster branch resolution and reduces stalls.
Load-Use Hazard Detection : Load instructions introduce additional hazards because load data becomes available later in the pipeline. On encountering a load use hazard, The hazard detection unit freezes the PC, stalls IF/ID, inserts bubble(s), and waits until valid data becomes available.

TESTING AND VERIFICATION : 

test_1 : Forwarding chain, the code used is - 
        addi x1, x0, 1
        add  x2, x1, x1     ← needs x1 (from EX/MEM)
        add  x3, x2, x2     ← needs x2 (from EX/MEM), x1 (from MEM/WB)
        add  x4, x3, x3     ← needs x3 (from EX/MEM)
        add  x5, x4, x4     ← needs x4 (from EX/MEM)
        add  x6, x5, x5     ← needs x5 (from EX/MEM)
        
        Expected: x1=1, x2=2, x3=4, x4=8, x5=16, x6=32
<img width="1812" height="622" alt="image" src="https://github.com/user-attachments/assets/eb80f2c5-0730-48b4-91db-a37551edfcb7" />











