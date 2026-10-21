Environment：Innovus 20.10、Quantus 19.1.3、GPDK045。
Symptom：报错信息及发生阶段。
Root Cause：QRC/LEF 自动层映射不匹配。
Debug Process：检查 Layer Map、Tech LEF、QRC 配置及错误日志。
Solution：依据工具手册编写 CCL 格式 Layer Map，并通过 -lefTechFileMap 指定。
Verification：独立 extractRC 成功，记录寄生电阻、电容统计。
