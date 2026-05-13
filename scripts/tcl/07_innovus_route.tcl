##############################################################
# Description : Run Routing
# History     : Created by Yanfuti
##############################################################

source scripts/00_common_initial_settings.tcl
source scripts/yanfuti_procs.tcl

### variables
set current_step "07_innovus_route"
set before_step  "06_innovus_clockopt"
set reports_dir "${reports_root}/${current_step}"
set data_dir "${data_root}/${current_step}"
file mkdir $reports_dir
file mkdir $data_dir

### restore design
restoreDesign ${data_root}/${before_step}/${before_step}.enc.dat $design

### initial options
set timing_report_enable_auto_column_width true
set_table_style -no_frame_fix_width -nosplit
set_global report_timing_format {delay arrival slew load fanout edge phase cell pin_location phys_info hpin net instance arc cell delay arrival required}

### change optmization views
set_interactive_constraint_modes [all_constraint_modes -active]
source scripts/viewDefinition.prects.tcl
set_propagated_clock [all_clocks]
set_max_transition -clock_path 200 [all_clocks ] -override
set_max_transition -data_path 400 [all_clocks ] -override
set_interactive_constraint_modes {}

### common optimization settings
setDesignMode -process 45
setAnalysisMode -analysisType onChipVariation -cppr both

### ndr (Non-Default Rule) and route types
add_ndr -width {Metal1 0.12 Metal2 0.14 Metal3 0.14 Metal4 0.14 Metal5 0.14 Metal6 0.14 Metal7 0.14 Metal8 0.14 Metal9 0.14 } -spacing {Metal1 0.12 Metal2 0.14 Metal3 0.14 Metal4 0.14 Metal5 0.14 Metal6 0.14 Metal7 0.14 Metal8 0.14 Metal9 0.14 } -name cts_2w2s
create_route_type -name cts_route -non_default_rule cts_2w2s -bottom_preferred_layer Metal5 -top_preferred_layer Metal8
## net type : top trunk leaf
set_ccopt_property route_type cts_route -net_type trunk 
set_ccopt_property route_type cts_route -net_type top

### routing related settings
setDesignMode -topRoutingLayer Metal9 -bottomRoutingLayer Metal1
setNanoRouteMode -routeWithTimingDriven true
setNanoRouteMode -routeWithSiDriven true
setNanoRouteMode -routeWithLithoDriven true ;# DFM redundant via insertion
setNanoRouteMode -drouteFixAntenna true -routeInsertAntennaDiode true
setNanoRouteMode -routeAntennaCellName "ANTENNA" -routeAddAntennaInstPrefix "ROUTE_ANT_"

### fix macros and ports
dbSet [dbGet top.insts.cell.subClass block -p2].pStatus fixed
dbSet [dbGet top.terms.name * -p].pStatus fixed

### create path groups
group_path -name reg2reg -from [all_registers] -to [all_registers]
group_path -name in2reg -from [all_inputs] -to [all_registers]
group_path -name reg2out -from [all_registers] -to [all_outputs]
group_path -name in2out -from [all_inputs] -to [all_outputs]
setPathGroupOptions reg2reg -effortLevel high
setPathGroupOptions in2reg -effortLevel low
setPathGroupOptions reg2out -effortLevel low
setPathGroupOptions in2out -effortLevel low

### set dont use cells
setDontUse *X1 true
setDontUse *X20 true

### run routing (global route, track assignment, detail route)
routeDesign -globalDetail
#Number of victim nets: 0
#Number of aggressor nets: 0

### save design
file delete -force ${data_dir}/${current_step}.enc*
saveDesign ${data_dir}/${current_step}.enc

### reports and check
## timing
file mkdir myreports/${current_step}
setAnalysisMode -checkType setup
report_analysis_summary -late > myreports/${current_step}/report_analysis_summary.late.rpt
report_timing -path_type full_clock -net -nworst 1 -check_type setup -max_paths 500 > myreports/${current_step}/report_timing.late.full.rpt
report_timing -net -nworst 1 -check_type setup -max_paths 500 > myreports/${current_step}/report_timing.late.short.rpt

setAnalysisMode -checkType hold
report_analysis_summary -early > myreports/${current_step}/report_analysis_summary.early.rpt
report_timing -path_type full_clock -net -nworst 1 -check_type hold -max_paths 500 > myreports/${current_step}/report_timing.early.full.rpt
report_timing -net -nworst 1 -check_type hold -max_paths 500 > myreports/${current_step}/report_timing.early.short.rpt

## physical check
reportGateCount
verify_drc -limit 99999 > myreports/${current_step}/verify_drc.rpt
verifyConnectivity -error 99999 -report myreports/${current_step}/verifyConnectivity.rpt
set rblkg_prefix "MACRO_PG_RBLKG_RAIL"
deleteRouteBlk -name $rblkg_prefix
checkPlace > myreports/${current_step}/checkPlace.rpt

### exit Innovus
exit

##############################################################
# END
##############################################################
