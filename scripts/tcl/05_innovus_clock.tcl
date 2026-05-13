##############################################################
# Description : Run Clock Tree Synthesis
# History     : Created by Yanfuti
##############################################################

source scripts/00_common_initial_settings.tcl
source scripts/yanfuti_procs.tcl

### variables
##set current_step "05_innovus_clock"
##set before_step  "04_innovus_placeopt"
set reports_dir "${reports_root}/${current_step}"
set data_dir "${data_root}/${current_step}"
file mkdir $reports_dir
file mkdir $data_dir

### initial options

### restore design
##restoreDesign ${data_root}/${before_step}/${before_step}.enc.dat $design

### set dont use cells
setDontUse *X1 true
setDontUse *X20 true
setDontUse *DLY* true

### clock cells selection (latency (insertion delay), skew, clock power, clock em, long common path(cppr), duty cycle)
set_ccopt_property buffer_cells {CLKBUFX12 CLKBUFX16 CLKBUFX6 CLKBUFX8}
set_ccopt_property clock_gating_cells TLATNTSCA*
# set_ccopt_property inverter_cells {}
set_ccopt_property use_inverters false

### ccopt spec options
set_ccopt_property effort extreme
set_ccopt_property max_fanout 16
set_ccopt_property target_skew 50
set_ccopt_property target_max_trans 150
set_ccopt_property target_insertion_delay auto
## sink_type (leaf)
# set_ccopt_property sink_type -pin <pin_name> ${type_name}
# auto        The pin type is automatically determined by CCOpt.
# through     This is a through pin. Trace the clock tree through this pin.
# stop        This is a stop pin. When defining the clock trees, CCOpt stops searching for the parts of a clock tree at the stop pins.
# ignore      This is an ignore pin. CCOpt stops searching for the parts of the clock tree at ignore pins and it does not attempt to balance the insertion delay of the ignore pins.
# exclude     An exclude pin. Exclude this pin from the clock tree.

### ndr (Non-Default Rule) and route types
add_ndr -width {Metal1 0.12 Metal2 0.14 Metal3 0.14 Metal4 0.14 Metal5 0.14 Metal6 0.14 Metal7 0.14 Metal8 0.14 Metal9 0.14 } -spacing {Metal1 0.12 Metal2 0.14 Metal3 0.14 Metal4 0.14 Metal5 0.14 Metal6 0.14 Metal7 0.14 Metal8 0.14 Metal9 0.14 } -name cts_2w2s
create_route_type -name cts_route -non_default_rule cts_2w2s -bottom_preferred_layer Metal5 -top_preferred_layer Metal8
## net type : top trunk leaf
set_ccopt_property route_type cts_route -net_type trunk 
set_ccopt_property route_type cts_route -net_type top
# set_ccopt_property routing_top_min_fanout 50000

### generate and read ccopt spec
delete_ccopt_clock_tree_spec
create_ccopt_clock_tree_spec -file ./${design}.ccopt_spec.tcl
source ./${design}.ccopt_spec.tcl

### cts route options
set_ccopt_property use_estimated_routes_during_final_implementation false

### routing related settings
setDesignMode -bottomRoutingLayer Metal1 -topRoutingLayer Metal9
setNanoRouteMode -routeWithTimingDriven true

### run ccopt
ccopt_design -cts -prefix ccopt -expandedViews -outDir myreports/ccopt_reports

### set all clocks to propagated
set_interactive_constraint_modes [all_constraint_modes -active]
set_propagated_clock [all_clocks]
set_interactive_constraint_modes {}

### route clock nets (with seperate globalDetailRoute command to minimize drc)
deselectAll
selectNet -clock
dbSet selected.wires.status routed
dbSet selected.vias.status routed 
globalDetailRoute -select 
deselectAll
selectNet -clock
dbSet selected.wires.status fixed
dbSet selected.vias.status fixed

### save design
file delete -force ${data_dir}/${current_step}.enc*
saveDesign ${data_dir}/${current_step}.enc

### reports and check
file mkdir myreports/${current_step}
## ccopt
report_ccopt_clock_trees > myreports/${current_step}/report_ccopt_clock_trees.rpt
report_ccopt_skew_groups > myreports/${current_step}/report_ccopt_skew_groups.rpt

## timing
setAnalysisMode -checkType setup
report_timing -path_type full_clock -net -nworst 1 -check_type setup -max_paths 500 > myreports/${current_step}/report_timing.late.full.rpt
report_analysis_summary -late > myreports/${current_step}/report_analysis_summary.late.rpt
setAnalysisMode -checkType hold
report_timing -path_type full_clock -net -nworst 1 -check_type hold -max_paths 500 > myreports/${current_step}/report_timing.early.full.rpt
report_analysis_summary -early > myreports/${current_step}/report_analysis_summary.early.rpt

## physical check
reportGateCount
verify_drc -limit 99999 > myreports/${current_step}/verify_drc.rpt
checkPlace > myreports/${current_step}/checkPlace.rpt

### exit Innovus
###exit

##############################################################
# END
##############################################################
