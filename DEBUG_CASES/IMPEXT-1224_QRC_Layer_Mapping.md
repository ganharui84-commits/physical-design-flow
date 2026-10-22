Environment：Innovus 20.10、Quantus 19.1.3、GPDK045。
Symptom：报错信息及发生阶段。
Root Cause：QRC/LEF 自动层映射不匹配。
Debug Process：检查 Layer Map、Tech LEF、QRC 配置及错误日志。
Solution：依据工具手册编写 CCL 格式 Layer Map，并通过 -lefTechFileMap 指定。
Verification：独立 extractRC 成功，记录寄生电阻、电容统计。
阶段：POST-ROUTE
在之前的cmd配置中，set extract Mode 选用了高精度RC提取模型（-engine postRoute -effortlevel high)，输入opt命令后，innvous在优化之前会调用IQuantas进行高精度的rc提取，这个工具在提取的时候会加载QRC Tech File和Tech LEF，生成一份layer mapping帮助它们建立映射关系。问题出在QRC Tech与LEF并没有成功映射：ERROR: (IMPEXT-1224):Consecutive cut layers 'via10_nocap' and 'via10_cap'   found in Quantus QRC technology file  but not in LEF data of Innovus. 后面跟着：ERROR: (LS_PLACEOPT::runCurrentState):Internal failure executing '::LS_PLACEOPT::PR:doExtrInit'
根据日志给出的路径查看自动生成的Layer Map Log,也可以发现没有给via10_cap建立对应的关系，但是更值得注意的是列表截止在Via10 -> via10_nocap 。却没有Metal11->metal11_conn，而GPDK45的完整工艺连接结构中恰好包含这些层，所以优先怀疑：QRC Tech File 包含更完整的顶层金属及特殊电容层结构，而 Innovus 加载的 LEF 没有对应的完整层定义。下一步先检查当前设计中有几层：dbGet head.layers.name
<img width="781" height="744" alt="image" src="https://github.com/user-attachments/assets/573a82b2-9a87-4e2a-9831-73c929a63c5e" />
dbGet后发现确实存在M11和Via10，所以上面怀疑的LEF缺少金属层并不成立。
<img width="2588" height="30" alt="image" src="https://github.com/user-attachments/assets/55b6da4b-616e-4ff3-a65d-a2654ac150ec" />
