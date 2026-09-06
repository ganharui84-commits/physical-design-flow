在做完place_opt后的报告中发现高达11ns的setup违例，DRV正常的同时有报出十万条 IMPESI -3025的WARNING
<img width="857" height="916" alt="屏幕截图 2026-09-03 214344" src="https://github.com/user-attachments/assets/61b1309a-0cbe-41c0-ab1d-8c2bc8527b67" />
<img width="988" height="655" alt="屏幕截图 2026-09-03 214849" src="https://github.com/user-attachments/assets/c9f27ec0-90d1-494f-8009-9089cceed477" />
首先怀疑是max_transition设置的过大导致的没有DRV违例而setup违例。但是查看setup.tcl时发现max_transition设置的反而偏小。即工具查表所做的线性外推是由于trantsition过小而做的
<img width="318" height="25" alt="image" src="https://github.com/user-attachments/assets/0c6321f2-1546-44a1-b1e7-476eed52a14d" />
由过小的transition而导致setup违例，很有可能是因为工具在修transition的时候插入了过多的buffer导致Congesition/density爆了，从而没有多余的地方去修setup。然而检查density/congesition发现指标正常，甚至偏小
<img width="458" height="52" alt="image" src="https://github.com/user-attachments/assets/72c60561-7846-46c5-b734-a6913171535a" />
对这种情况重新翻看STA书籍，重新给出的解释为：在约束transition的路径上，因为插入了过多的buffer而导致累加起来的delay过大。因此，即使小的transition增大了required time但由过多的cell累加起来的delay也增大了arrived time，并且增大程度比required time更甚，从而导致了setup violations
以下是我所理解的针对这种情况的理论知识：setup的值主要由Data transition & clock transition二维查表决定，此时的阶段是PRE-CTS，没有时钟树，clock transition是设置的理想值（本设计中clock transition设置的值更小，因此对setup应当是起的正面作用），所以对data transition进行考虑，但同时已知transition较小，在Data &clocktransition都较小的情况下setup的值也比较小，此时对slack应当是利好的（slack=required-arrived）。则从arrived的层面考虑，已知data transition是根据input transition & output capatiience查表得到，即工具会插入大量buffer以降低input transition从而降低data transition。而信号穿过这些buffer是存在延迟的，即经过每个触发器的delay都不大，但是累加起来足以造成过大的arrived time，从而导致slack<0，因此导致setup违例。
使用report_timing -max_paths 1 -nworst 1 -path_type full_clock -net查看最差的违例路径可以明显验证理论的正确性（接近一个T的required time与超过一个T的arrived time，仅仅十分之一个T的setup，报告中大量的INV,BUF）如图。
<img width="2208" height="1141" alt="屏幕截图 2026-09-05 182117" src="https://github.com/user-attachments/assets/a443d2f3-4327-4fc0-8846-b86de2c39ce4" />
修复策略即放宽max_transition的约束，一般给时钟周期的10%-15%，因为套用的14nm的flow，此时也对clock_max_transition修改为0.2（通常取时钟周期的5%左右），不同工艺节点设置的capatience也不同，这里不过多赘述。
transition放宽后重新做PRE-CTS，随后用report_timing -to mcore0/ahb0/r_reg_hslave_1/DFF/D -path_type full_clock -net报表之前的最差路径，如图时序收敛，setup大于重新做之前的
<img width="1177" height="343" alt="image" src="https://github.com/user-attachments/assets/62d260e4-fae3-407e-a882-adf1712d46bb" />
