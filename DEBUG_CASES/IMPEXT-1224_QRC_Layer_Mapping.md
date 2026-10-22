# IMPEXT-1224 — IQuantus RC Extraction Layer Mapping Failure

## 1. Environment

| Item | Configuration |
|---|---|
| Design | LEON |
| Implementation Tool | Cadence Innovus 20.10-p004_1 |
| Extraction Engine | Integrated Quantus 19.1.3-s155 |
| Technology | GPDK045 |
| Design Stage | Post-Route |
| Extraction Effort | High |
| Coupling Extraction | Enabled |

**Result:** RC Extraction successfully completed after explicitly configuring the LEF-to-QRC layer mapping.

---

## 2. Symptom — 问题现象

在 Post-Route 阶段，将寄生参数提取模式配置为：

```tcl
setExtractRCMode \
    -engine postRoute \
    -effortLevel high \
    -coupled true
```

随后执行：

```tcl
optDesign -postRoute -setup -hold
```

工具在 Post-Route Optimization 初始化阶段调用 Integrated Quantus，进行寄生 RC 提取。

此时出现：

```text
ERROR: (IMPEXT-1224):
Consecutive cut layers 'via10_nocap' and 'via10_cap'
found in Quantus QRC technology file
but not in LEF data of Innovus.
```

后续报错：

```text
ERROR: (LS_PLACEOPT::runCurrentState):
Internal failure executing
'::LS_PLACEOPT::PR:doExtrInit'
```

**Initial Analysis**

`IMPEXT-1224` 是首先需要处理的关键错误，而 `PR:doExtrInit` 失败属于后续连带错误。

问题发生在 **IQuantus RC Extraction 初始化阶段**，而不是 Setup/Hold Optimization 算法本身。

---

## 3. Investigation — Debug 过程

### Step 1 — 检查自动生成的 Layer Map

根据 Innovus Error Log 提供的路径，找到 Quantus 自动生成的：

`extr.leon.layermap.log`

其中相关映射为：

```tcl
Metal9   metal9_conn
Via9     via9
Metal10  metal10_conn
Via10    via10_nocap
```

观察到：

- `Via10` 映射到了 `via10_nocap`。
- 自动映射没有包含 `Metal11 → metal11_conn`。
- QRC 报错还涉及 `via10_cap`，但自动映射中没有对应项。

这里需要注意：**QRC 中存在 `via10_cap`，并不意味着数字 Tech LEF 必须具有相应的映射。**

GPDK045 的顶层工艺连接模型区分了普通金属互连与特殊电容结构：

```text
                metal11_conn
                  /     \
                 /       \
      via10_nocap         via10_cap
           |                  |
      metal10_conn         CapMetal
```

当前数字 Tech LEF 中的普通 Via10 对应 `via10_nocap` 是合理的。

因此，最值得进一步调查的不是 Via10 名称不同，而是**自动映射为何缺少 Metal11，以及工艺层映射是否完整**。

### Step 2 — 检查 Innovus Database 和 Tech LEF

首先查询当前数据库中的工艺层：

```tcl
dbGet head.layers.name
```

<image source="https://github.com/user-attachments/assets/55b6da4b-616e-4ff3-a65d-a2654ac150ec" />

发现数据库中存在 `M11` 和 `Via10`。

继续查询层类型：

```tcl
set m11   [dbGet -p head.layers.name M11]
set via10 [dbGet -p head.layers.name Via10]

dbGet $m11.type
dbGet $via10.type
```

结果：

```text
M11   → routing
Via10 → cut
```

随后检查项目实际使用的 Technology LEF：

```bash
sed -n '590,660p' <Tech_LEF文件路径>
```

确认普通顶层结构为：

```text
Metal11  ROUTING
   |
Via10    CUT
   |
Metal10  ROUTING
```

**阶段结论：**

Metal10、Via10、Metal11 的基本层定义和顺序没有明显异常。

但这只能排除当前检查范围内的 Layer Type 问题，**不能证明整份 LEF 完全正确，也不能直接证明 Metal11 映射缺失就是唯一 Root Cause。**

### Step 3 — 对比项目自带 QRC Layer Map

在项目工艺资料中找到：

```text
library/tech/qrc/qrc.map
```

该文件包含 LEF Layer 与 QRC Technology Layer 的显式对应关系。

其中包含：

```tcl
Metal10  metal10_conn
Metal11  metal11_conn
Via10    via10_nocap
```

对比结果：

| LEF Layer | Auto-generated Map | Project qrc.map |
|---|---|---|
| Metal10 | metal10_conn | metal10_conn |
| Metal11 | Missing | metal11_conn |
| Via10 | via10_nocap | via10_nocap |
| Cont | cont_ndiff | cont_poly |

项目自带的 `qrc.map` 为构建显式映射提供了参考。

这进一步支持了 **Automatic Layer Mapping Incomplete / Inconsistent** 的假设。

需要强调：以上差异是证据线索，具体哪一项单独导致 `IMPEXT-1224`，仍需进一步隔离验证。

### Step 4 — 首次显式映射测试失败

尝试直接使用项目自带的 `qrc.map`：

```tcl
setExtractRCMode \
    -lefTechFileMap ../library/tech/qrc/qrc.map

extractRC
```

得到：

```text
ERROR: (IMPEXT-1438):
Only CCL style syntax of layer map file
is supported using
"setExtractRCMode -lefTechFileMap".
```

说明当前文件未被此接口成功解析。

随后通过：

```tcl
man setExtractRCMode
```

确认 Innovus 20.10 对 `-lefTechFileMap` 的要求，参考手册重新整理 CCL Layer Map。

需要注意：原始 `qrc.map` 本身并没有发现明显的 Tcl 续行语法错误，因此不能直接断言原始文件存在语法错误。

---

## 4. Solution — 解决方案

根据 Innovus 20.10 的工具手册与项目工艺映射信息，新建 `lefTechFile.map`。

采用以下 CCL 格式：

```tcl
extraction_setup \
    -technology_layer_map \
        Poly     poly_conn \
        Cont     cont_poly \
        Metal1   metal1_conn \
        Via1     via1 \
        Metal2   metal2_conn \
        Via2     via2 \
        Metal3   metal3_conn \
        Via3     via3 \
        Metal4   metal4_conn \
        Via4     via4 \
        Metal5   metal5_conn \
        Via5     via5 \
        Metal6   metal6_conn \
        Via6     via6 \
        Metal7   metal7_conn \
        Via7     via7 \
        Metal8   metal8_conn \
        Via8     via8 \
        Metal9   metal9_conn \
        Via9     via9 \
        Metal10  metal10_conn \
        Via10    via10_nocap \
        Metal11  metal11_conn \
        Oxide    Oxide
```

保留已有的 QRC Technology File 和 Tech LEF，不直接修改底层工艺数据。

在 Innovus 中指定显式 Layer Map：

```tcl
set map_file [file normalize \
    ../library/tech/qrc/lefTechFile.map]

if {![file isfile $map_file]} {
    error "Layer map file not found: $map_file"
}

setExtractRCMode \
    -engine postRoute \
    -effortLevel high \
    -coupled true \
    -lefTechFileMap $map_file

getExtractRCMode
```

通过这种方式，显式提供 LEF 与 QRC Technology Layer 的对应关系，不再完全依赖工具的自动映射结果。

---

## 5. Verification — 独立验证

为避免引入 Post-Route Optimization 的额外变量，从保存的 Post-Route DB 恢复，单独执行：

```tcl
extractRC
```

最终日志：

```text
Extraction of Geometries DONE

Number of Extracted Resistors     : 706029
Number of Extracted Ground Caps   : 752135
Number of Extracted Coupling Caps : 246346

Parasitic Network Creation DONE

IQuantus Fullchip Extraction DONE
```

提取统计：

| Metric | Value |
|---|---:|
| Extracted Nets | 45,368 |
| Resistors | 706,029 |
| Ground Capacitors | 752,135 |
| Coupling Capacitors | 246,346 |
| Parallel Processes | 6 |
| Real Time | 4 min 27 s |

**Verification Result：PASS**

Integrated Quantus 已成功完成 Fullchip RC Extraction，原来的 `IMPEXT-1224` 和 `IMPEXT-1438` 不再阻止提取。

---

## 6. Root Cause Analysis

### Confirmed Findings

1. 原始自动 Layer Mapping 无法满足当前 IQuantus 的工艺层匹配要求。
2. 自动生成的 Layer Map 未包含 `Metal11 → metal11_conn`。
3. 检查范围内的 Tech LEF 普通顶层 Routing/Cut 定义正常。
4. 使用重新编写的显式 CCL Layer Map 后，Fullchip RC Extraction 成功。

### Remaining Uncertainty

虽然自动映射缺少 Metal11 是重要异常，但成功配置同时涉及多处映射关系及文件表达形式的改变。

因此目前**尚未通过单变量实验，确定 `IMPEXT-1224` 究竟由哪一个具体映射差异触发**。

另外，缺少 `CapMetal` 的数字 Tech LEF 本身不一定错误。最终成功提取也不需要显式映射 `via10_cap`，因此不能把缺少该特殊层当成已确认的 Root Cause。

### Root Cause Conclusion

本次问题可归类为：

**QRC/LEF Technology Layer Mapping Incompatibility**

即 Integrated Quantus 的自动工艺层映射未能满足当前提取要求，通过显式提供适配的 Layer Map 解决了初始化失败。

---

## 7. Engineering Takeaways

- 根据最早出现的有效 Error 定位失败模块，而不是仅根据最外层 `optDesign` 命令判断。
- 区分 LEF Layer、QRC Technology Layer、Technology Stack 和实际 Routing Connectivity。
- 自动映射失败时，优先对照项目提供的工艺映射资料。
- 对于版本敏感的 EDA 命令，以实际安装版本的 `man` 文档为准。
- 使用独立 `extractRC` 隔离故障，避免反复运行完整 Post-Route Optimization。
- RC Extraction 成功只证明当前配置下提取流程可以完成，**不等于 Post-Route Setup/Hold、DRC 或 Sign-off 已收敛**。

**Next Step：** 将已验证的 `-lefTechFileMap` 配置集成到主 Flow，重新检查 Post-Route Optimization、Timing、DRV 和 Connectivity 结果。
