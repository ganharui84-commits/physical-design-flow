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
 ##布局阶段

本阶段所用到的脚本参考：02_innovus_floorplan.tcl  floorplan_calculate.tcl
规划floorplan的大小前先通过floorplan_calculate.tcl计算好大概需要的面积，然后进行规划。在此LEON项目中，因为四个Hard Macro都是长方形，所以core采取长方形的规划方式。考虑到将来的电源环规划（针对四个Hard Macro单独打电源环而不是在core与die之间打环），所以给
