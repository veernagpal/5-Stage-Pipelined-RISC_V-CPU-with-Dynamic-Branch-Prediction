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
Obtained waveform : 
<img width="1812" height="622" alt="image" src="https://github.com/user-attachments/assets/eb80f2c5-0730-48b4-91db-a37551edfcb7" />

The waveform confirms correct operation through these observations. First, stall_PC remains permanently low throughout the entire sequence — the forwarding unit resolves every dependency without inserting a single bubble, proving that the EX/MEM and MEM/WB forward paths are both active and correct. Second, ForwardA_EX and ForwardB_EX are seen having 2'b10 (forwarding from EX/MEM) as we want the most recent data to be forwarded. Third, registers x1 through x6 settle to 1, 2, 4, 8, 16, 32 respectively — the exact doubling sequence (observe write_data_WB and rd_WB) — confirming that every forwarded value was correct and no stale register data was used at any point.

test_2 :  Load-Use Hazard
What it tests: A load instruction (lw) followed immediately by an instruction that consumes the loaded value. This is the one hazard that forwarding alone cannot solve — the data comes out of memory at the end of the MEM stage, which is too late to forward to an EX-stage ALU that needs it in the very next cycle. The hazard detection unit must detect this, freeze the PC and IF/ID register for one cycle, and insert a bubble into ID/EX, after this stall, the data gets forwarded from MEM/WB to EX.   
Code:      addi x1, x0, 10
           sw   x1, 0(x0)
           lw   x2, 0(x0)
           add  x3, x2, x1     ← RAW hazard on x2: lw is in EX when add is in ID
           addi x4, x0, 99
           Expected: x1=10, x2=10, x3=20, x4=99
Obtained waveform : 
<img width="1817" height="830" alt="image" src="https://github.com/user-attachments/assets/b30fb6f6-ae96-4c51-9892-dbb532722dec" />

The waveform shows stall_PC going high for exactly one cycle at the point where lw is in EX and add is in ID — the hazard unit has correctly identified MemRead_EX=1 and rd_EX == rs1_ID. Simultaneously, flush_ID_EX pulses high on the same cycle, inserting a NOP bubble into the ID/EX register so the add instruction does not proceed with a stale x2. On the cycle after the stall resolves, ForwardA_EX is seen as 2'b01 — the MEM/WB path is now forwarding the freshly loaded value of x2 to the ALU. The final register values x2=10, x3=20 confirm that the correct loaded value reached the add instruction, and x4=99 confirms that the pipeline recovered cleanly and continued executing after the stall.

test_3 : Memory operations 
What it tests: Two store instructions write known values to different memory addresses, followed by two loads reading them back, and finally an add combining the loaded values. This tests the complete store-to-load data path through the data memory module and verifies that word-addressed memory indexing, MemWrite, and MemRead control signals all work correctly end to end.
Code :    addi x1, x0, 42
          addi x2, x0, 7
          sw   x1, 0(x0)      → mem[0] = 42
          sw   x2, 4(x0)      → mem[1] = 7
          lw   x3, 0(x0)      → x3 = 42
          lw   x4, 4(x0)      → x4 = 7
          add  x5, x3, x4     → x5 = 49
Obtained waveform : 

<img width="1752" height="857" alt="image" src="https://github.com/user-attachments/assets/bf5050ae-00a4-4903-aa74-ccc2aa090c5b" />

The waveform shows MemWrite_MEM pulsing high on two consecutive cycles as the two sw instructions pass through the MEM stage, with ALU_result_EX holding addresses 0 and 4 respectively and write_data_MEM holding 42 and 7 — confirming correct store execution. Subsequently MemRead_MEM goes high on the two lw cycles and read_data_MEM returns 42 and then 7, confirming that the memory retained the stored values correctly. A one-cycle stall is visible before add x5 executes — the hazard unit correctly detecting the load-use hazard between lw x4 and the immediately following add. The final values x3=42, x4=7, x5=49 confirm that both memory addresses were written and read back correctly, and that the forwarding path delivered the loaded values to the ALU accurately

test_4 : JAL and JALR
What it tests:
JAL (jump-and-link) and JALR (jump-and-link register) instructions. These are unconditional jumps that must redirect the PC to a new target and simultaneously write PC+4 (the return address) to a destination register. JAL computes its target as PC+immediate while JALR computes its target as rs1+immediate. Both are resolved in the EX stage, requiring a 2-instruction flush of the IF and ID stages.

Code :    addi x1, x0, 5
          jal  x10, +8         → jump to addr=12, x10 = 8 (return address)
          addi x2, x0, 99      → addr=8  SKIPPED
          addi x3, x0, 42      → addr=12 jal lands here
          addi x10, x0, 28     → set x10=28 for jalr target
          jalr x11, x10, 0     → jump to addr=28, x11 = 24 (return address)
          addi x4, x0, 99      → addr=24 SKIPPED
          addi x5, x0, 77      → addr=28 jalr lands here
          Expected: x1=5, x2=0, x3=42, x10=8(pc+4 WB) then 28, x11=24, x4=0, x5=77
Waveform Obtained :          

<img width="1797" height="792" alt="image" src="https://github.com/user-attachments/assets/8127e9b7-b5c0-4ddc-ab90-0aa92550ba8d" />


The waveform shows Jump_EX going high twice — once for each jump instruction passing through EX. On both occasions, flush_IF_ID_reg and flush_ID_EX_reg pulse high simultaneously, inserting two bubbles and squashing the instructions that were fetched from the wrong path. For JAL, jump_target_EX reads 12 and Jalr_EX is 0; for JALR, jump_target_EX reads 28 and Jalr_EX is 1, confirming the correct target computation path was selected in each case. pc_plus4_WB reads 8 when the JAL commits at WB and 24 when the JALR commits, and write_data_WB matches these values exactly — confirming the link address writeback logic is correct. x2=0 and x4=0 confirm that the skipped instructions never committed to the register file, proving the flush was effective on both occasions.

test_5 :  Branch Taken and Not-Taken (Cold Start + Branch RAW Hazard)

What it tests: Two versions of the same program that together cover the fundamental branch mechanics end to end. Both versions have a sub instruction immediately before the beq — one instruction apart — which means sub is still in EX when beq reaches ID. This is a RAW hazard on the branch source register, so the hazard unit must fire a stall, wait one cycle, then forward ALU_result_MEM to the branch comparator via the ID-stage forwarding path. The branch decision is therefore made on forwarded data, not stale register file data.

Version A tests the not-taken path — x3=2 after the sub, so the condition x3==0 is false, the branch falls through, and every instruction after it must commit normally. This verifies that no spurious flush fires when a branch is correctly predicted not-taken.

Version B tests the taken path — x3=0 after the sub, the branch jumps over three instructions to the target at addr=36, and those three instructions must be completely squashed. This is a cold-start mispredict scenario: the BTB has never seen this branch before, the predictor defaults to not-taken, the branch actually takes — so a mispredict is detected, the two wrongly-fetched instructions are flushed, and the PC is redirected to the correct target. Both the flush mechanism and the PC redirect logic get exercised together

Version A Code : addi x1, x0, 5 
                 addi x2, x0, 3 
                 sub x3, x1, x2 
                 beq x3, x0, 24  The branch is not taken - so there is no misprediction as the predictor starts off cold in weakly not taken state
                 addi x5, x0, 11 
                 addi x6, x0, 22 
                 add x7, x5, x6 
                 addi x8, x0, 99
                 Expected: x1=5, x2=3, x3=2, x5=11, x6=22, x7=33, x8=99. Branch not taken, everything runs
Obtained Waveform :


<img width="1763" height="862" alt="image" src="https://github.com/user-attachments/assets/9de22fb3-52ff-409f-8267-be8d67056627" />


During this test, stall_PC briefly pulses high for one cycle, indicating that the hazard detection unit has correctly detected a RAW dependency between the sub instruction in the EX stage and the beq instruction currently in the ID stage. During this stall cycle, branch_resolved remains low, preventing the branch comparator from making an incorrect early decision before valid data becomes available. Once the stall clears, ForwardA_ID changes to 2'b10, showing that the value of x3 is successfully forwarded from ALU_result_MEM directly into the ID-stage branch comparator. In the following cycle, branch_resolved goes high, allowing the branch comparison to proceed with valid forwarded operands. Since x3 = 2, the branch condition evaluates false, causing branch_taken_ID to remain 0. Because the predictor had already predicted Not-Taken by default, the actual outcome matches the prediction, so branch_mispredict also remains 0. As expected, flush_IF_ID_reg stays low throughout execution since no incorrect speculative instruction needs to be discarded and the sequential fall-through path is correct. After branch resolution, the predictor trains toward Not-Taken by decrementing the BHT entry from 01 to 00. The remaining instructions continue executing normally, with registers x5, x6, x7, and x8 committing the expected values 11, 22, 33, and 99 respectively.












