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
