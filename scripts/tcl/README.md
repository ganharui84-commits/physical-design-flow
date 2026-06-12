本リポジトリは、デジタルICバックエンド設計における、初期セットアップから最終的なGDSII出力（テープアウト）までのフィジカルデザイン（物理設計）の全工程をカバーしています。標準的なフローに加えて、実用的な自動化スクリプトや、SDC（Synopsys Design Constraints）の作成・最適化における高度なテクニックも収録しています。
## 设计初始化与环境导入 (Design Initialization & Setup / 設計の初期化とセットアップ)

本阶段主要通过三个核心 Tcl 脚本完成物理设计环境的搭建。

### 1. 基础环境与库路径配置 (`00.tcl`)
主要负责设置项目名称、报告存储路径，以及各类物理库的查找路径。
*   **Tech LEF**: 定义 45nm 工艺的全局物理规则（如金属层、通孔、设计规则 Design Rules、天线规则 Antenna Rules）。不包含具体逻辑电路。
*   **Cell/Macro LEF**: 提供设计中用到的物理单元抽象模型。
    *   `gsclib045_macro.lef` 等：标准单元 (Standard Cell) 的物理信息（如 NAND, FF）。
    *   `MEM1_256X32.lef` 等：宏单元 (Macro) 的物理信息。
    *   `pdkIO.lef` 等：芯片引脚 (I/O Pad) 的物理信息，用于连接外部封装。
*   **PEX Tech File (`qrcTechFile`)**: 寄生参数提取 (Parasitic Extraction) 专用的工艺文件，包含 3D 寄生参数查找表。为工具计算真实金属导线上的寄生电阻 (R) 与电容 (C) 提供基准，是完成最终时序收敛的关键。

### 2. 设计导入与全局电源地连接 (`01.tcl`)
核心命令为 `init_design`，负责将网表与物理库结合。
*   **设置电源网络**: 通过 `set init_pwr_net` 和 `set init_gnd_net` 定义逻辑电源网名 (VDD) 与地网名 (VSS)。
*   **全局挂靠 (Connect PG)**: 使用 `globalNetConnect` 在全局范围内查找所有 `pgpin` 类型的物理引脚，将其逻辑上挂靠到 VDD/VSS 网络上。
    *   *注：这一步至关重要。只有完成挂靠，后续在 Powerplan 阶段打环 (Ring)、走条带 (Stripe) 及铺设 rail 时，工具才能正确匹配物理连线与逻辑网络，避免开路或短路 DRC 违例。*

### 3. MMMC 时序视角配置 (`viewDefinition.tcl`)
多模式多端角 (Multi-Mode Multi-Corner) 视角的配置机制，采用自底向上的逻辑：
1.  **Library Set (Cell Delay 基础)**: 指向 `.lib` 文件，定义标准单元在特定 PVT 条件下的内部延迟，反映晶体管工艺角（如 FF, SS）。
2.  **RC Corner (Net Delay 基础)**: 指向 `qrcTechFile` 并设定温度系数，定义互连线的寄生 RC 提取参数。
3.  **Delay Corner (物理延迟集合)**: 将 `Library Set` 与 `RC Corner` 组合。例如将最慢的晶体管与最悲观的寄生网络组合为 `slow_rcworst`，用于 Setup 检查。
4.  **Constraint Mode (工作模式约束)**: 定义芯片的工作模式（如 Functional 正常工作、Scan-Shift 测试扫描），对应不同的 SDC 时序约束文件。
5.  **Analysis View (全局分析视角)**: 将特定的 `Delay Corner` (物理环境) 与 `Constraint Mode` (工作模式) 绑定，供工具最终计算 Setup 和 Hold 的时序收敛情况。

## 核心规划与宏单元布局 (Floorplan & Macro Placement / フロアプランとマクロ配置)

本阶段核心目标：确定芯片整体物理尺寸，完成宏单元摆放，并插入必要的基础物理单元以满足底层工艺设计规则 (DRC)。

**关联脚本**: `02_innovus_floorplan.tcl`, `floorplan_calculate.tcl`

### 1. 核心面积与尺寸推导 (Core Sizing Strategy)
在进行 `floorPlan` 设定前，采用“面积-间距反推法”来确定精确的物理尺寸：
*   **预估总面积**: 优先运行 `floorplan_calculate.tcl`，结合设计利用率 (Utilization) 算出大致所需的 Core 面积。
*   **推导长宽 (Aspect Ratio)**: 针对本设计（如包含 4 个长方形 Hard Macro），由于策略是**为 Macro 单独打电源环，而非依赖全局 Core Ring**，因此：
    1.  先测量 Macro 之间的最小间距 (Spacing) 要求。
    2.  测量 Macro 到 Core 边界的最短距离。
    3.  据此确定 Core 长/宽其中一边的最小极限值。
    4.  最后用“总面积 $\div$ 已定边长”推导另一边，完成尺寸规划。
*   **边界裕量 (Core-to-Die Margin)**: Core 与 Die 之间的间距通常设定为 1 个 Standard Cell Row 的高度，以最大化面积利用率。

### 2. 宏单元摆放法则 (Macro Placement Rules)
*   **引脚朝向 (Pin Orientation / ピンの向き)**: Hard Macro 的数据引脚通常必须**朝向 Core 的中心区域**。这能最大限度缩短 Macro 与标准单元 (Std Cell) 进行数据交换时的连线长度，优化时序 (Timing)。
*   **保留连续布线区**: 摆放 Macro 时，应尽量把留给 Std Cell 的区域规整为**正方形或大块的连续矩形**，避免出现狭长、破碎的通道 (Narrow Channel)，从而有效提升布线资源的利用率并减少拥塞。
*   **精细微调**: 粗摆放后，使用 EDA 工具自带的 Floorplan Tool 进行对齐和坐标微调。

### 3. 物理约束与基础单元插入 (Physical Constraints & Setup)
完成 Macro 摆放后，必须执行以下关键步骤以封锁物理边界并满足代工厂 DRC 要求：
*   **添加光晕 (Add Halo / ソフト・ブロッケージ)**: 给所有 Macro 添加 Halo (Soft Blockage)。为宏单元的电源环 (Macro Ring) 以及引脚出线预留物理空间，防止 Std Cell 贴靠过近。
*   **引脚分配 (Pin Assignment)**: 结合数据流向，合理规划芯片顶层 I/O Pin 的位置。
*   **插入物理单元 (Physical Cells Insertion)**:
    *   **End Cap Cell (エンドキャップセル)**: 插入在每个 Std Cell Row 的两端，保护行末标准单元的栅极免受制造过程中的物理损伤。
    *   **Well Tap Cell (ウェルタップセル)**: 按照工艺库规定的最大间距均匀打入，将 N-Well 和 P-Well 连接到电源和地，这是**防止闩锁效应 (Latch-up)** 的强制要求。

## 3. 全局电源网络规划 (Power Network Planning / 電源網設計)

本阶段核心目标：构建稳健的电源供给网络 (PDN, Power Delivery Network)，在满足底层绕线资源需求的前提下，有效抑制电压降 (IR Drop) 与电迁移 (EM) 违例。

**关联脚本**: `03_innovus_powerplan.tcl`

### 3.1 供电拓扑结构 (Power Delivery Topology)
全局电源网络严格遵循 **Ring $\rightarrow$ Stripe $\rightarrow$ Rail** 的自顶向下构建顺序：
1.  **Macro Ring (宏单元电源环 / マクロ電源リング)**: 针对本设计特征，优先围绕 4 个 Hard Macro 单独打环。
2.  **Power Stripe (电源条带 / 電源ストライプ)**: 在 Ring 铺设完成后构建，其两端与 Macro Ring 的端口实现物理连接，形成主干电网。
3.  **Power Rail (电源导轨 / 電源レール)**: 最后铺设于最底层 (通常为 M1)，与 Stripe 连接，直接为标准单元 (Standard Cell) 供电。

### 3.2 电源条带布线策略 (Stripe Routing Strategy)
在定义 Power Stripe 时，需通过精准的参数控制以避免物理冲突并保证电气可靠性：
* **坐标与重叠规避**: 当VDD Stripe 与 VSS Ring 处于同一金属层时，存在物理相交导致短路的风险。必须通过精确计算起始偏移 (`start_offset`) 与组间距 (`set_to_set_distance`)，使 Stripe 的走线完美避开异极性的 Ring；或在 `addStripe` 脚本中运用 `-break_at` 等断开参数，强制 Stripe 在跨越异极性 Ring 时自动断开连线。
* **DRC 规则合规**: 查阅代工厂 (Foundry) 工艺规则表，严格设定 Stripe 之间的最小间距 (`spacing`)，以规避长平行金属线带来的间距违例 (Long-line Spacing Violation)。
* **宏单元内网隔离 (Macro Internal Blockage)**: 宏单元内部通常自带高层电源网络。打 Stripe 时需合理运用工具的 Macro Blockage 属性，防止 Stripe 错误地穿越宏单元内部，干扰 SRAM 自身的供电完整性(使用addStripe的-break_at或者手动在Macro区域创建一个Routing Blockage
* **可靠性评估**: 结合整体芯片功耗评估，设定足够的 Stripe 宽度与分布密度，这是防止静态/动态电压降 (IR Drop) 和电迁移 (Electromigration / エレクトロマイグレーション) 的核心手段。

### 3.3 阶梯式供电网络与通孔优化 (Stepped Mesh & Via Optimization)
在规划由高层金属 (如 M9) 向底层 M1 供电的 `layer_change_range` 时，需综合权衡 IR Drop 与布线拥塞 (Congestion) 风险：

**痛点分析 (Direct Drop-down Issues):**
* **绕线拥堵**: 若允许从 M9 直接垂直打孔至 M1，且高层 Stripe 密度较大，会形成密集的“通孔柱 (Via Pillars)”，彻底切断中低层金属的连续布线轨道。
* **局部压降**: 若为了缓解拥堵而拉宽高层 Stripe 间距，会导致 M1 上的供电接入点跨度过大。由于 M1 金属线径细、方块电阻大，电流在 M1 上的长距离传输极易在节点中段引发严重的局部 IR Drop 违例。

**优化方案：阶梯式供电 (Stepped Power Supply / 階層的給電):**
* **执行策略**: 引入中层金属（如 M5/M6）作为过渡层铺设次级 Stripe，形成“高层 $\rightarrow$ 中层 $\rightarrow$ 底层”的阶梯式网格。
* **工程收益 (Pros)**: 
    1.  **缓解 IR Drop**: 极大缩短了电流在底层高阻抗 M1 上的传输路径。
    2.  **释放绕线空间**: 错开了高层-中层 Via 与中层-底层 Via 的物理位置。M2/M3 等底层金属获得了更连续的布线空间，便于标准单元进行局部复杂连线 (Local Routing)。
* **工程妥协 (Cons)**: 次级 Stripe 会消耗部分中层金属的可用布线资源，需在 `place_opt_design` 后观察 Congestion Map 进行密度平衡。


进行placement opt前的约束：通过setDesignMode告诉工具芯片节点，便于后续opt，同时setAnalysisMoe开启OCV与cppr，并使用set_timing_derate设置合适的悲观量。关于setAnalysisMode -analysisType onchipVariation的man文档，官方指出的是此约束仅可以起到给capature路径找不同operating condition的作用，例如分析setup时给capature端找ff corner,并不涉及悲观量的设置，故需要set_timing_derate给适当的悲观量。setOptMode可以在工具进行opt插入buffer时给插入的buffer进行命名，此项目暂时不考虑功耗，故-powerEffort none
