# F-14A CADC — Source Document to Specification Mapping

This document maps each specification document to the original source PDFs/OCR text files that provided its content.

---

## Source Document Index

### AiResearch Report 71-7266 (Scanned PDFs with OCR)
| PDF File | OCR Text File | Report Pages | Content Summary |
|----------|---------------|-------------|-----------------|
| p1-4-to-p1-34-.pdf | p1-4-to-p1-34-.txt | 1-4 through 1-34 | **Section 1: HARDWARE** — MOS theory, system timing, all 6 circuit function descriptions (PMU/PDU/SLF/RAS/SL/ROM), pin assignments, device counts, chip sizes, package outlines, data path interconnections, hardware system arrangement |
| p1-35-to-p2-28-.pdf | p1-35-to-p2-28-.txt | 1-35 through 2-28 | Hardware system continued (ROM photo, module config, circuit arrangements, control word formats, data flow walkthrough), then **Section 2: SOFTWARE PROGRAMMING** — math model & scaling, mechanization drawings, computer program drawings, coding, executive control (20-bit executive word), software systems & considerations (propagation delays, throughput stats), programming examples (AoA correction, EPR function) |
| p2-29-to-p2-46-.pdf | p2-29-to-p2-46-.txt | 2-29 through 2-46 | Programming examples continued (EPR zones, glove vane schedule, glove vane limit, wing sweep rate limit, maneuver flap deadband, switch thresholds), **Inflight Diagnostics** (BIT self-test, single failure analysis, PMU/PDU test operands) |
| p3-1-to-B1-.pdf | p3-1-to-B1-.txt | 3-1 through Appendices A/B/C | **Section 3: COMPUTER AIDS** (simulation programs, CalComp plotter), **Appendix A: Booth's Algorithm**, **Appendix B: Non-restoring Division**, **Appendix C: Gray Code Conversion** |
| ap1-26-97.pdf | ap1-26-97.txt | N/A (1997 paper) | Ray Holt's unpublished 1970 paper (declassified 1998) — CPU & Memory architecture overview, design constraints, number system, processor parallelism/pipelining, functional unit descriptions (PMU/PDU/SLF/SL/RAS/ROM), instruction format, system operation, module configuration (28 circuits total), system block diagrams |

### Ray Holt's MOS Device Characteristics Notebook (Scanned PDFs with OCR)
| PDF File | OCR Text File | Chip | Content Summary |
|----------|---------------|------|-----------------|
| Rays-...-Chapter-1-944111-PMU.pdf | Rays-...-Chapter-1-944111-PMU.txt | PMU (944111) | Logical specification, system term definitions, general description (Booth's algorithm), inputs/outputs, propagation delays, electrical characteristics (VDD, power dissipation, logic levels), output drive capability, input loading, logic diagram reference, system device count summary (74,442 total) |
| Rays-...-Chapter-2-944112-PDU.pdf | Rays-...-Chapter-2-944112-PDU.txt | PDU (944112) | Logical specification, non-restoring division algorithm, inputs/outputs, electrical characteristics (VDD -14V, ground), output drive capability, input loading specs |
| Rays-...-Chapter-3-944113-SLF.pdf | Rays-...-Chapter-3-944113-SLF.txt | SLF (944113) | Logical specification, control word (4 bits), inputs (U/P/L/D/CW), outputs (Line 1/Line 2/B/B'/C), limit function (pick L/P/U logic), CW mode table (AND, Gray code, swap), logic diagram |
| Rays-...-Chapter-4-944114-RAS.pdf | Rays-...-Chapter-4-944114-RAS.txt | RAS (944114) | Logical specification, 16-word random access R/W storage, 5-bit control word, register select table, inhibit write, non-destructive readout, timing (WA control/WO data) |
| Rays-...-Chapter-5-944118-Steering.pdf | Rays-...-Chapter-5-944118-Steering.txt | SL (944118) | Logical specification, 3-channel serial data multiplexer, 15-bit control word, Output 1/2/3 selection codes, EXT1–EXT13 inputs, CW pass-through, addition/subtraction modes |
| Rays-...-Chapter-6-944125-ROM.pdf | Rays-...-Chapter-6-944125-ROM.txt | ROM (944125) | Logical specification, 2560-bit storage (128×20), address management (reset/retain/increment/load/add/sub), chip select (3-bit mask decode), parity error detection, sequential/random access modes |
| Rays-...-Chapter-7-System-Info.pdf | Rays-...-Chapter-7-System-Info.txt | System | Pin assignment table (all 6 chip types), timing generator calculations, clock generation details |

### Readable PDFs (with text layer)
| PDF File | Pages | Content Summary |
|----------|-------|-----------------|
| lsistate-97.pdf | 10 | Ray Holt's 1998 LSI State-of-the-Art paper — design history, technology context (1968-69), design constraints (40 sq in, 10W, flexibility), architecture trade-offs, parallel multi-processor approach, pipelining concept, Moore's Law comparison, microprocessor definition discussion, delivery timeline |
| CADC_Module_Specification.pdf | 4 | Condensed module specification for all 7 reconstructed modules — PMU interface, PDU interface, SLF interface, RAS interface, SL interface, Control ROM + Sequencer interface (48-bit microinstruction format), I/O Bridge interface |
| F-14-CADC-Design-Sequence-v1.00.pdf | 9 | Design sequence narrative — system design (Steve Geller), logic design (Ray Holt), AMI chip manufacturing, hardware prototype, software simulation (Bill Holt), math equations (Bill McCormick), ROM programming (70,000 bits), chip photos, first flight Dec 1970 |
| toc-illustrations.pdf | 4 | Table of contents and illustrations list for AiResearch Report 71-7266 — complete page index for all sections, figures, and appendices |

---

## SPEC: CADC_System_Requirements.md

**Content:** System overview, architecture summary, key design parameters, data format, system timing, module configuration, chip summary (device counts, chip sizes, packages), redundancy/self-test, FPGA considerations, external interfaces, mathematical functions, verification strategy.

### SOURCES:

| Source | Pages/Sections | Information Extracted |
|--------|----------------|---------------------|
| **p1-4-to-p1-34-.pdf** (OCR: p1-4-to-p1-34-.txt) | Pages 1-4 (Report p1-4 to p1-7) | Supply voltage, system timing (5 MHz osc → 375 kHz Φ1/Φ2, bit time 2.666μsec, 20 bit times/word, WA/WO alternation, word mark at T18, 512 OPs/frame), data format (20-bit fractional fixed-point, sign + 19 data, 2's complement, bit weights), circuit function overview intro |
| **p1-4-to-p1-34-.pdf** (OCR: p1-4-to-p1-34-.txt) | Pages 4-31 (Report p1-7 to p1-34) | Device counts & chip sizes for all 6 chips: PMU=1063 devices, PDU=1241 devices (141×157 mils), SLF=743 devices (120×130 mils), RAS=2330 devices (115×130 mils), SL=771 devices (128×133 mils), ROM=1269-3268 devices (143×150 mils); package types (24-pin DIP for PMU/PDU/SLF/SL, 14-pin DIP for RAS/ROM) |
| **p1-35-to-p2-28-.pdf** (OCR: p1-35-to-p2-28-.txt) | Pages 1-7 (Report p1-35 to p1-42) | Module configuration (3 modules: PMU/PDU/SLF each with SL+RAS+ROMs), ROM allocation (data ROMs vs. control ROMs), control word path, 20-bit control word breakdown per module, general circuit arrangement, hardware flexibility discussion, 512-OP frame cycle walkthrough |
| **p1-35-to-p2-28-.pdf** (OCR: p1-35-to-p2-28-.txt) | Pages 29-30 (Report p2-21 to p2-22) | Throughput statistics (300 multiplies, 105 divides, 225 adds/subs, 75 limits, 4 square roots, 20 AND/OR, 55 IF transfers, 25 discrete in, 21 discrete out, 15 A/D, 23 D/A per frame = ~50% capacity), propagation delay constraints |
| **p2-29-to-p2-46-.pdf** (OCR: p2-29-to-p2-46-.txt) | Pages 17-18 (Report p2-46) | Inflight diagnostics overview — single failure detection, dual-channel redundancy, BIT circuitry, self-test approach |
| **ap1-26-97.pdf** (OCR: ap1-26-97.txt) | Pages 1-2 (Introduction) | Design constraints (40 sq in, ≤10W, flexibility), computational requirements (polynomial, division, multiply, add, subtract, limits, sqrt, AND/OR, conditional/unconditional transfer, discrete/digital I/O) |
| **ap1-26-97.pdf** (OCR: ap1-26-97.txt) | Pages 4-5 (Number System, Processor Parallelism) | Fixed-point fractional 20-bit, 2's complement choice, word length rationale, serial data transfer decision, pipelining architecture (multiple functional units: PMU/PDU/SLF/SL/RAS/ROM) |
| **ap1-26-97.pdf** (OCR: ap1-26-97.txt) | Pages 7 (Timing), 15 (System Operation) | Timing details (375 kHz, bit time, word, OP, frame mark), total 28 circuits breakdown (1 PMU, 1 PDU, 1 SLF, 3 RAS, 3 SL, 19 ROM) |
| **Rays-...-Chapter-1-944111-PMU.txt** | Page 2 | System device count totals: 74,442 active MOS devices total, 62,092 in ROM storage; per-chip breakdown table |
| **lsistate-97.pdf** | Pages 1-2, 6-8 | Design history & constraints (size/power/flexibility/cost), architecture decisions (parallel multi-processor, pipelining, serial transfer), F-14A delivery timeline, Moore's Law comparison |
| **CADC_Module_Specification.pdf** | Pages 1-4 | Module interface summary for all 7 reconstructed modules |
| **toc-illustrations.pdf** | Pages 1-4 | Complete table of contents and figure list for Report 71-7266 (page number cross-reference) |

---

## SPEC: CADC_Top_Level_Spec.md

**Content:** System architecture block diagram, data flow per operation (WA compute phase, WO transfer phase), pipelining, timing generator sub-module, top-level VHDL entity, internal signal interconnections, integration requirements, end-to-end tests, FPGA implementation notes.

### SOURCES:

| Source | Pages/Sections | Information Extracted |
|--------|----------------|---------------------|
| **p1-4-to-p1-34-.pdf** (OCR: p1-4-to-p1-34-.txt) | Pages 1-3 (Report p1-4 to p1-6) | System timing architecture — 5 MHz master osc, Φ1/Φ2 at 375 kHz, bit time definition, word time (T0–T19), WA/WO alternation, word mark (T18), OP time, frame mark, 512 OPs/frame |
| **p1-35-to-p2-28-.pdf** (OCR: p1-35-to-p2-28-.txt) | Pages 5-7 (Report p1-40 to p1-42) | Module control word breakdown (how CW splits: 5 bits to RAS, 15 bits to SL, SLF shares 4 RAS select bits), inter-module data flow walkthrough (frame mark → ROM reset → CW shift → SL routing → arithmetic → data transfer cycle) |
| **p1-35-to-p2-28-.pdf** (OCR: p1-35-to-p2-28-.txt) | Pages 17-22 (Report p2-9 to p2-22) | Executive control (20-bit executive word controlling inputs/outputs/processor), executive bit assignments (D/A updates, digital outputs, BITE, sensor memory, ROM enables, frame mark), software/hardware relationship, propagation delay considerations |
| **ap1-26-97.pdf** (OCR: ap1-26-97.txt) | Pages 5-6 (Processor Parallelism) | Pipeline concurrency definition, multiple functional units operating simultaneously, module independence, expandability |
| **ap1-26-97.pdf** (OCR: ap1-26-97.txt) | Pages 7 (Timing) | Timing diagram description (375 kHz clock, bit time, word types, frame structure) |
| **ap1-26-97.pdf** (OCR: ap1-26-97.txt) | Pages 15-17 (System Operation) | System operation and instruction format — 28 total circuits, 3-module arrangement, data ROM/control ROM paths, instruction word flow from ROM through SL to units |
| **Rays-...-Chapter-7-System-Info.txt** | Pages 5-6 | Clock generator timing calculations, timing waveform details |
| **lsistate-97.pdf** | Pages 6-7 | Architecture decisions — parallel multi-processor approach, pipelining for throughput, synchronization between CPUs |
| **CADC_Module_Specification.pdf** | Pages 1-4 | All module interfaces that the top-level integrates |
| **F-14-CADC-Design-Sequence-v1.00.pdf** | Pages 1, 4 | System design block diagram (Steve Geller's concept), software simulation approach for verification |

---

## SPEC: PMU_Module_Spec.md

**Content:** 20×20-bit signed fractional multiplication, Booth's algorithm, serial I/O (original) vs. parallel (FPGA), I/O pin definitions, timing, VHDL entity, functional requirements, verification tests.

### SOURCES:

| Source | Pages/Sections | Information Extracted |
|--------|----------------|---------------------|
| **p1-4-to-p1-34-.pdf** (OCR: p1-4-to-p1-34-.txt) | Pages 4-6 (Report p1-7 to p1-9) | PMU circuit function description — accepts serial M (multiplicand) and R (multiplier) in WO, produces rounded product via parallel algorithm in WA, product shifted out in next WO while new inputs arrive; Booth's algorithm reference (Appendix A); inputs (MIN, R, Φ1, Φ2, T18, WO, VDD, GND), outputs (MO, P); pin assignments (Figure 1-3); 24-pin DIP package (Figure 1-4); 1063 active MOS devices, chip size 150×53 mils |
| **p1-4-to-p1-34-.pdf** (OCR: p1-4-to-p1-34-.txt) | Page 6 (Report p1-9) | PMU timing and propagation delay considerations (referenced to Source Control Drawing 944111), continuous operation capability (no control word needed) |
| **Rays-...-Chapter-1-944111-PMU.pdf** (OCR text) | Pages 2-4 | **Detailed PMU logical specification:** system term definitions (bit time, word time, WA/WO), general description (Booth's algorithm mandate, parallel internal operation), inputs & outputs spec (Φ1, Φ2, VDD, GND, T18 signal, M input, R input, M output, P output), propagation delay requirements (M→M register: 125ns, R→R register: 125ns, M register→M output: 250ns, LSB adder→P output: 250ns), system considerations (connection diagram, timing interface), electrical characteristics (VDD=-14V, logic levels: input "0" -3V max, input "1" -9V min; output "0" 0V, output "1" VDD), output drive capability (75kΩ ∥ 40pF load), input loading specs |
| **p3-1-to-B1-.pdf** (OCR: p3-1-to-B1-.txt) | Pages 19-end (Report Appendix A) | **Booth's Algorithm** — detailed description: signed 2's complement multiplication method, no sign sensing required, bit-pair encoding rules (add/subtract/shift), shifting rules (sign extension), worked examples |
| **ap1-26-97.pdf** (OCR: ap1-26-97.txt) | Pages 7, 12 | PMU functional description — serial I/O, Booth's multiplication, continuous pipelined operation without instruction word |
| **p2-29-to-p2-46-.pdf** (OCR: p2-29-to-p2-46-.txt) | Pages 17-18 (Report p2-46) | PMU inflight diagnostic test operands — 5 sets of M,R operands detecting >98% single failures |
| **p3-1-to-B1-.pdf** (OCR: p3-1-to-B1-.txt) | Pages 1-2 (Report p3-1 to p3-2) | Single failure analysis program for PMU — determination of test word sets |
| **Rays-...-Chapter-7-System-Info.txt** | Page 3 | PMU pin assignment table (944111, 24 pins): pin 1=GRD, pin 5=M IN, pin 8=P OUT, pin 9=M OUT, pin 10=Φ1, pin 18=R IN, pin 20=VDD, etc. |
| **lsistate-97.pdf** | Page 2 | Design constraints leading to Booth's algorithm selection (efficiency for size/power) |
| **CADC_Module_Specification.pdf** | Page 1 (Section 1) | Reconstructed PMU interface: clk, rst, start, busy, done, operand_a, operand_b, result |

---

## SPEC: PDU_Module_Spec.md

**Content:** 20-bit signed fractional division, non-restoring division algorithm, serial I/O (original) vs. parallel (FPGA), I/O pin definitions, pre-condition (|dividend| < |divisor|), VHDL entity, functional requirements, verification tests.

### SOURCES:

| Source | Pages/Sections | Information Extracted |
|--------|----------------|---------------------|
| **p1-4-to-p1-34-.pdf** (OCR: p1-4-to-p1-34-.txt) | Pages 7-9 (Report p1-10 to p1-14) | PDU circuit function description — accepts serial D (dividend) and Z (divisor) in WO, produces truncated quotient via parallel algorithm in WA, quotient shifted out in next WO; non-restoring division algorithm reference (Appendix B); inputs (D, Z, Φ1, Φ2, T18, WO, VDD, GND), output (Q); PN 944112; pin assignments (Figure 1-6); 24-pin DIP (Figure 1-7); 1241 active MOS devices, chip size 141×157 mils |
| **Rays-...-Chapter-2-944112-PDU.pdf** (OCR text) | Pages 2-4 | **Detailed PDU logical specification:** system term definitions, general description (non-restoring division mandate), inputs & outputs, electrical characteristics (VDD=-14V), power dissipation specs (-55°C to +125°C, ≤15% variance from calculated), clock characteristics, logic levels (input "0" -3V max, input "1" -9V min), output drive capability (75kΩ ∥ 40pF), input loading |
| **p3-1-to-B1-.pdf** (OCR: p3-1-to-B1-.txt) | Pages ~25-end (Report Appendix B) | **Non-restoring Division Algorithm** — detailed description: positive/negative partial remainder steps, quotient bit determination, final correction step |
| **ap1-26-97.pdf** (OCR: ap1-26-97.txt) | Pages 7-9 | PDU functional description — serial I/O, non-restoring division, continuous pipelined operation, chip photograph reference |
| **p2-29-to-p2-46-.pdf** (OCR: p2-29-to-p2-46-.txt) | Pages 17-18 (Report p2-46) | PDU inflight diagnostic test operands — 5 sets of D,Z operands detecting >98% single failures |
| **p3-1-to-B1-.pdf** (OCR: p3-1-to-B1-.txt) | Pages 1-2 (Report p3-1 to p3-2) | Single failure analysis program for PDU — test word determination |
| **Rays-...-Chapter-7-System-Info.txt** | Page 3 | PDU pin assignment table (944112, 24 pins) |
| **CADC_Module_Specification.pdf** | Page 2 (Section 2) | Reconstructed PDU interface: clk, rst, start, busy, done, dividend, divisor, quotient, remainder |

---

## SPEC: SLF_Module_Spec.md

**Content:** Main ALU operations (ADD/SUB/AND/OR/XOR/NOT/SHL/SHR/NEG/ABS/GRAY2BIN/BIN2GRAY/LOAD/STORE_TMP/PASS), limit function (U/P/L register picking), control word modes, Gray code conversion, B/B'/C logic outputs, status flags, VHDL entity.

### SOURCES:

| Source | Pages/Sections | Information Extracted |
|--------|----------------|---------------------|
| **p1-4-to-p1-34-.pdf** (OCR: p1-4-to-p1-34-.txt) | Pages 9-16 (Report p1-12 to p1-21) | SLF circuit function description — PN 944113; performs logical operations with 4-bit control word; fundamental operation is limit function with U(upper)/P(parameter)/L(lower) registers; pick logic (L if P<L, U if P>U, else P); Line 1/Line 2 data outputs; B output (true in WA if P picked), B' (complement of B in WA), C output (true in WO under specific conditions); control word mode table (AND operation, Gray code conversion, P input switching, data swap); inputs (U, P, L, D, CW, Φ1, Φ2, T18, WO, VDD, GND); outputs (Line 1, Line 2, C, B, B'); 743 active MOS devices, 120×130 mils, 24-pin DIP |
| **Rays-...-Chapter-3-944113-SLF.pdf** (OCR text) | Pages 2-4+ | **Detailed SLF logical specification:** control word format (4 bits, arriving t15–t18 of WA), formal operation description (data inputs U/P/L, logic input D, data outputs Line 1/Line 2, logic outputs B/B'/C), complete CW action table with D input combinations (LSB/MSB bit assignments, switching P input to Line 1, AND products of P∧U and P∧L to Line 2, Gray code conversion of P, output with LSB=1, output with MSB=1, C output conditions), logic diagram reference (Figure 4) |
| **p3-1-to-B1-.pdf** (OCR: p3-1-to-B1-.txt) | Pages ~27-end (Report Appendix C) | **Gray Code Conversion** algorithm — Gray→Binary and Binary→Gray bit-by-bit XOR formulae |
| **ap1-26-97.pdf** (OCR: ap1-26-97.txt) | Pages 9 | SLF functional description — limit function with U/P/L registers, comparison logic, AND/OR, Gray code, conditional/unconditional branching |
| **p1-35-to-p2-28-.pdf** (OCR: p1-35-to-p2-28-.txt) | Page 6 (Report p1-41) | Module 3 control word breakdown — bits 1-4 select SLF RAS registers (also select SLF functions), bit 5 write, bits 6-20 select SLF steering data paths |
| **Rays-...-Chapter-7-System-Info.txt** | Page 3 | SLF pin assignment table (944113, 24 pins): pin 1=CW IN, pin 7=B' OUT, pin 8=C' OUT, pin 9=ONE OUT, pin 10=TWO OUT, pin 11=Φ1, pin 15=L IN, pin 16=U IN, pin 19=T18, pin 20=D IN |
| **CADC_Module_Specification.pdf** | Page 2 (Section 3) | Reconstructed SLF interface: clk, rst, acc_in, alu_op, write enables, acc_out, tmp_out, flags |
| **lsistate-97.pdf** | Page 6 | Design rationale for including limit function in hardware (frequently used, saves computation time) |

---

## SPEC: RAS_Module_Spec.md

**Content:** 16-word random access R/W storage, 5-bit control word, register selection, write enable, inhibit write, non-destructive readout, serial (original) vs parallel (FPGA) access, VHDL entity.

### SOURCES:

| Source | Pages/Sections | Information Extracted |
|--------|----------------|---------------------|
| **p1-4-to-p1-34-.pdf** (OCR: p1-4-to-p1-34-.txt) | Pages 17-22 (Report p1-21 to p1-26) | RAS circuit function description — PN 944114; 16-word random access R/W storage; serial I/O during WO; non-destructive readout; 5-bit control word during WA (4-bit address + 1-bit write enable); register select table (0000=Reg 1 through 1111=Reg 16); inhibit write input; timing (WAI→CW enter, WO1→data shift, WA2→data shift out, WO2→new CW); inputs (DI, CW, IW, T18, WO, Φ1, Φ2, VDD, GND); output (DO); 2330 active MOS devices, 115×130 mils, 14-pin DIP |
| **Rays-...-Chapter-4-944114-RAS.pdf** (OCR text) | Pages 2-4+ | **Detailed RAS logical specification:** system term definitions, 16-word R/W storage mandate, 5-bit CW during WA (bits [3:0] register select, bit [4] write enable), non-destructive readout, inhibit write (active during WO, false during WA), register selection table, data I/O timing, electrical characteristics |
| **ap1-26-97.pdf** (OCR: ap1-26-97.txt) | Pages 12-13 | RAS functional description — 16-word random access R/W, 5-bit instruction word, register select codes (0000=Reg 16, 0001=Reg 1, etc.), inhibit write, actual chip photograph reference |
| **Rays-...-Chapter-7-System-Info.txt** | Page 3 | RAS pin assignment table (944114, 14 pins): pin 1=DATA IN, pin 3=DATA OUT, pin 4=WO, pin 8=GRD, pin 11=Φ1, pin 12=IW, pin 14=VDD |
| **CADC_Module_Specification.pdf** | Pages 2-3 (Section 4) | Reconstructed RAS interface: clk, rst, read_addr, read_data, write_addr, write_data, write_en |

---

## SPEC: SL_Module_Spec.md

**Content:** 3-channel serial data multiplexer, 15-bit control word format, Output 1/2/3 selection codes, EXT1-EXT13 input mapping, addition/subtraction in-transit, CW pass-through, FPGA source/destination mapping, VHDL entity.

### SOURCES:

| Source | Pages/Sections | Information Extracted |
|--------|----------------|---------------------|
| **p1-4-to-p1-34-.pdf** (OCR: p1-4-to-p1-34-.txt) | Pages 22-28 (Report p1-26 to p1-31) | SL circuit function description — PN 944118; 3-channel serial digital data multiplexer; 15-bit CW (last 15 of 20-bit CW); Output 1 selection codes (4 bits, 16 codes: EXT1-EXT10, EXT13, EXT1, EXT9+EXT4, EXT10+EXT4, EXT4+EXT8, EXT2/EXT8); Output 2 selection codes (4 bits, including T19 code); Output 3 selection codes (7 bits, extended combinations with Z1/Z2 intermediate values); addition/subtraction during data transfer; Output 3 can perform A+B+C; 771 active devices, 128×133 mils, 24-pin DIP |
| **Rays-...-Chapter-5-944118-Steering.pdf** (OCR text) | Pages 2-4+ | **Detailed SL logical specification:** 3-channel multiplexer mandate, 15-bit CW during WA (first 5 bits pass through to CW OUT), 13 data inputs (EXT1-EXT13), 4 outputs (Output 1, 2, 3, CW Out), complete Output 1/2/3 selection code tables with EXT input mappings, T18 signal, addition/subtraction capability |
| **ap1-26-97.pdf** (OCR: ap1-26-97.txt) | Pages 9-12 | SL functional description — 3-channel serial data multiplexer, 15-bit instruction word format (4+4+7 bits), complete Output 1/2/3 selection code tables with all EXT codes, Output 3 A+B+C addition feature, CW pass-through, zero-time add/subtract during transfer |
| **p1-35-to-p2-28-.pdf** (OCR: p1-35-to-p2-28-.txt) | Pages 5-6 (Report p1-40 to p1-41) | Module control word breakdown — how the 20-bit CW splits: first 5 bits to RAS (and SLF for register select), last 15 bits to SL; module 1/2/3 specific CW bit assignments (multiplicand select, multiplier select, divisor select, dividend select, limit selects, RAS storage data) |
| **Rays-...-Chapter-7-System-Info.txt** | Page 3 | SL pin assignment table (944118, 24 pins): pin 1=EXT12, pin 2=EXT2, pin 3=EXT4, pin 4=EXT3, pin 5=EXT6, pin 6=CW OUT, pin 7=OUT 2, pin 8=OUT 3, pin 14=EXT10, pin 15=EXT9, pin 16=EXT7, pin 17=EXT5, pin 18=EXT1, pin 19=EXT8, pin 20=EXT13, pin 21=EXT11 |
| **CADC_Module_Specification.pdf** | Page 3 (Section 5) | Reconstructed SL interface: src_ras, src_acc, src_tmp, src_pmu, src_pdu_q, src_pdu_r, src_io_in, src_const, sel controls, routed outputs |

---

## SPEC: ROM_Sequencer_Module_Spec.md

**Content:** ROM chip specification (2560-bit, 128×20, address management, chip select, parity), reconstructed 48-bit microinstruction format, sequencer operations (sequential/jump/branch/wait/call/return), data ROM, executive control, VHDL entity.

### SOURCES:

| Source | Pages/Sections | Information Extracted |
|--------|----------------|---------------------|
| **p1-4-to-p1-34-.pdf** (OCR: p1-4-to-p1-34-.txt) | Pages 28-31 (Report p1-31 to p1-34) | ROM circuit function description — PN 944125; 2560-bit storage (128 words × 20 bits); 20-bit serial address (7-bit word select + 3-bit chip select + 10 zeros); address management via internal register/counter (resettable, steppable/increment, retain, load, add, sub); logic input priority (R > increment/load/retain > add/sub); access period (WAcc) definition; data output (20-bit serial, wire-OR); parity error detection; F-14A uses only increment mode; 1269–3268 devices, 143×150 mils, 14-pin DIP |
| **Rays-...-Chapter-6-944125-ROM.pdf** (OCR text) | Pages 2-4+ | **Detailed ROM logical specification:** 2560-bit random/sequential access, 128×20-bit storage, address register/counter capabilities (reset, step, retain, load, add, sub), chip select field (3-bit mask decode, up to 8 ROMs per group), parity error output (state changes per data output, checked at Φ1 of T19→T0), wire-OR compatibility, data output timing |
| **p1-35-to-p2-28-.pdf** (OCR: p1-35-to-p2-28-.txt) | Pages 1-2 (Report p1-35 to p1-37) | ROM photo (3268 devices), module ROM allocation (Module 1: PMU + 3 data ROMs + 3 control ROMs; Module 2: PDU + 1 data ROM + 3 control ROMs; Module 3: SLF + 2 data ROMs + 3 control ROMs), ROM operating modes (data ROMs increment on WA, control ROMs increment on WO) |
| **p1-35-to-p2-28-.pdf** (OCR: p1-35-to-p2-28-.txt) | Pages 15-22 (Report p2-9 to p2-21) | **Executive control** — 20-bit executive word with bit assignments controlling: wing sweep D/A update, digital outputs, D/A updates, IFF, switches, BITE, sensor memory (Ps, Pt), counter shift out, frame mark, ROM enable bits (13-19: PMU data/control, PDU data/control, SLF data-1/data-2/control), discrete register step (bit 20) |
| **p1-35-to-p2-28-.pdf** (OCR: p1-35-to-p2-28-.txt) | Pages 28-29 (Report p2-20 to p2-21) | ROM enable strategy — executive bits 13-19 enable/disable ROM groups to save ROM chips (14 ROMs saved at cost of 4 executive ROMs = net 10 saved), programming flexibility trade-offs |
| **ap1-26-97.pdf** (OCR: ap1-26-97.txt) | Pages 12-13 | ROM functional description — 2560-bit device, 128×20-bit, address management (reset/retain/increment/load/add/sub), chip select (3-bit mask), wire-OR outputs, sequential access only in F-14A application |
| **Rays-...-Chapter-7-System-Info.txt** | Page 3 | ROM pin assignment table (944125, 14 pins): pin 1=RETAIN, pin 3=PARITY, pin 5=INCREMENT, pin 6=ADD, pin 7=SUB, pin 8=GRD, pin 9=RESET(FM), pin 10=LOAD, pin 11=T18, pin 12=Φ2, pin 13=Φ1, pin 14=VDD |
| **CADC_Module_Specification.pdf** | Pages 3-4 (Section 6) | Reconstructed microinstruction format (48-bit): NEXTCTL(47–40), NEXTADR(39–32), ALU_OP(31–28), ACCCTL(27–24), RASCTL(23–20), SL_ACC(19–16), SL_RAS(15–12), PMUCTL(11–8), PDUCTL(7–4), IOCTL(3–0) |
| **F-14-CADC-Design-Sequence-v1.00.pdf** | Pages 5-7 | ROM programming process — math equations → sequence → binary 1s and 0s (70,000 total), AMI format, paper tape submission, first chips March 1970 |

---

## SPEC: IO_Bridge_Module_Spec.md

**Content:** I/O channel definitions (sensor inputs: Ps/Qc/TAT/analog/digital; display outputs: Mach/altitude/airspeed/vspd; servo outputs: wing/flap/glove), IOCTL encoding, input latching, output holding registers, Gray-coded sensor pass-through, redundancy interface, VHDL entity.

### SOURCES:

| Source | Pages/Sections | Information Extracted |
|--------|----------------|---------------------|
| **p1-35-to-p2-28-.pdf** (OCR: p1-35-to-p2-28-.txt) | Pages 15-27 (Report p2-9 to p2-20) | Executive control I/O bits — D/A output updates (wing sweep, other displays), A/D multiplexer stepping, ADC data shift out format (12-bit ADC data within 20-bit word), sensor memory control (Ps, Pt counters), digital output updates, IFF update, switch updates, BITE control signals |
| **p1-35-to-p2-28-.pdf** (OCR: p1-35-to-p2-28-.txt) | Pages 30-36 (Report p2-23 to p2-28) | Programming examples showing I/O usage — angle-of-attack correction (sensor inputs Psi, Pti), EPR function (Pt2 input, ambient temperature), I/O data paths through steering to arithmetic units |
| **p2-29-to-p2-46-.pdf** (OCR: p2-29-to-p2-46-.txt) | Pages 1-16 (Report p2-29 to p2-43) | I/O-related programming examples — EPR zones (temperature range processing), glove vane schedule f1(M), glove vane limit schedule LIM(Δ), wing sweep rate limit mechanization (computed wing sweep command), maneuver flap deadband and rate limit, switch thresholds (Mach switch outputs S1-S5) |
| **p2-29-to-p2-46-.pdf** (OCR: p2-29-to-p2-46-.txt) | Pages 17-18 (Report p2-46) | BITE / inflight diagnostics — how diagnostic results feed the BITE circuitry, comparator output state verification |
| **ap1-26-97.pdf** (OCR: ap1-26-97.txt) | Pages 1-2 | System I/O overview — pressure sensors, temperature sensors, closed loop feedback inputs; outputs to pilot displays (altimeter, temperature, Mach, etc.) and aircraft control systems; digital and analog signal forms |
| **lsistate-97.pdf** | Pages 1-2, 6 | Design constraints affecting I/O — size (40 sq in PC board), 10W power budget, real-time computing requirement, sensor and actuator interface requirements |
| **CADC_Module_Specification.pdf** | Page 4 (Section 7) | Reconstructed I/O Bridge interface: clk, rst, io_in, io_out, io_ctrl, external sensor lines, actuator outputs |
| **F-14-CADC-Design-Sequence-v1.00.pdf** | Page 1 | System block diagram showing digital inputs (A/D or sensor), module I/O paths, output control paths |

---

## Summary: Cross-Reference Matrix

| Source ↓ / Spec → | SysReq | TopLevel | PMU | PDU | SLF | RAS | SL | ROM/Seq | IO Bridge |
|---|---|---|---|---|---|---|---|---|---|
| p1-4-to-p1-34-.pdf | ✓ timing, data fmt, chip summary | ✓ timing arch | ✓ **PRIMARY** pp1-7–1-9 | ✓ **PRIMARY** pp1-10–1-14 | ✓ **PRIMARY** pp1-12–1-21 | ✓ **PRIMARY** pp1-21–1-26 | ✓ **PRIMARY** pp1-26–1-31 | ✓ **PRIMARY** pp1-31–1-34 | |
| p1-35-to-p2-28-.pdf | ✓ module config, throughput | ✓ **PRIMARY** exec ctrl, data flow | ✓ CW format | ✓ CW format | ✓ CW format | ✓ CW format | ✓ CW format | ✓ ROM enables, exec | ✓ **PRIMARY** exec I/O bits |
| p2-29-to-p2-46-.pdf | ✓ diagnostics | | ✓ test operands | ✓ test operands | | | | | ✓ I/O examples, BIT |
| p3-1-to-B1-.pdf | | | ✓ **Booth's** (App A), failure analysis | ✓ **NonRestore** (App B), failure analysis | ✓ **Gray Code** (App C) | | | ✓ simulation, ROM format | |
| ap1-26-97.pdf | ✓ **PRIMARY** architecture | ✓ parallelism, timing | ✓ description | ✓ description | ✓ description | ✓ description | ✓ **DETAILED** codes | ✓ description | ✓ overview |
| Ch1-PMU notebook | ✓ device totals | | ✓ **PRIMARY** elec spec | | | | | | |
| Ch2-PDU notebook | | | | ✓ **PRIMARY** elec spec | | | | | |
| Ch3-SLF notebook | | | | | ✓ **PRIMARY** CW table | | | | |
| Ch4-RAS notebook | | | | | | ✓ **PRIMARY** elec spec | | | |
| Ch5-Steering notebook | | | | | | | ✓ **PRIMARY** codes | | |
| Ch6-ROM notebook | | | | | | | | ✓ **PRIMARY** addr mgmt | |
| Ch7-System notebook | | ✓ timing calcs | ✓ pin table | ✓ pin table | ✓ pin table | ✓ pin table | ✓ pin table | ✓ pin table | |
| lsistate-97.pdf | ✓ history, constraints | ✓ arch decisions | ✓ context | | ✓ limit rationale | | | | ✓ constraints |
| CADC_Module_Spec.pdf | ✓ module summary | ✓ all interfaces | ✓ FPGA interface | ✓ FPGA interface | ✓ FPGA interface | ✓ FPGA interface | ✓ FPGA interface | ✓ μinstr format | ✓ FPGA interface |
| Design-Sequence.pdf | | ✓ system design | | | | | | ✓ ROM programming | ✓ block diagram |
| toc-illustrations.pdf | ✓ page index | ✓ page index | ✓ figure refs | ✓ figure refs | ✓ figure refs | ✓ figure refs | ✓ figure refs | ✓ figure refs | |

