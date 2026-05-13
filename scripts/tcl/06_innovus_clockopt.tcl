##############################################################
# Description : Run Post-CTS Optimization
# History     : Created by Yanfuti
##############################################################

source scripts/00_common_initial_settings.tcl
source scripts/yanfuti_procs.tcl

### variables
set current_step "06_innovus_clockopt"
set before_step  "05_innovus_clock"
set reports_dir "${reports_root}/${current_step}"
set data_dir "${data_root}/${current_step}"
file mkdir $reports_dir
file mkdir $data_dir

### initial options
set timing_report_enable_auto_column_width true
set_table_style -no_frame_fix_width -nosplit
set_global report_timing_format {delay arrival slew load fanout edge phase cell pin_location phys_info hpin net instance arc cell delay arrival required}

### restore design
restoreDesign ${data_root}/${before_step}/${before_step}.enc.dat $design

### fix all clock routing
deselectAll
selectNet -clock
dbSet selected.wires.status fixed
dbSet selected.vias.status fixed

### change optmization views
set_interactive_constraint_modes [all_constraint_modes -active]
source scripts/viewDefinition.postcts.tcl
set_propagated_clock [all_clocks]
set_max_transition -clock_path 200 [all_clocks ] -override
set_max_transition -data_path 400 [all_clocks ] -override
set_interactive_constraint_modes {}

### common optimization settings
setDesignMode -process 45
setAnalysisMode -analysisType onChipVariation -cppr both ;# OCV
setOptMode -addInstancePrefix "POSTCTS_" -addNetPrefix "POSTCTS_NET_"
setOptMode -powerEffort none
setTieHiLoMode -maxFanout 2 -honorDontTouch true -honorDontUse true -prefix "POSTCTS_TIE_" -cell {TIEHI TIELO}
# setOptMode -maxDensity 0.7 -maxLength 500

### routing related settings
setDesignMode -bottomRoutingLayer Metal1 -topRoutingLayer Metal9
setNanoRouteMode -routeWithTimingDriven true

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
# setDontUse *DLY* true

### run post-cts optimization (place_opt_design -> optDesign)
optDesign -expandedViews -setup -hold -drv -outDir "myreports/${current_step}/innovus_clockopt" -postCTS -prefix "innovus_clockopt"

### save design
file delete -force ${data_dir}/${current_step}.enc*
saveDesign ${data_dir}/${current_step}.enc

### reports and check
## timing
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
checkPlace > myreports/${current_step}/checkPlace.rpt

### exit Innovus
exit

##############################################################
# END
##############################################################
