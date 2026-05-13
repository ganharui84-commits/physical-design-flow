##############################################################
# Description : Run Pre-CTS Optimization
# History     : Created by Yanfuti
##############################################################

source Desktop/project_data/scripts/00_common_initial_settings.tcl
source Desktop/project_data/scripts/yanfuti_procs.tcl

### variables
set current_step "04_innovus_placeopt"
set before_step  "03_innovus_powerplan"
set reports_dir "${reports_root}/${current_step}"
set data_dir "${data_root}/${current_step}"
file mkdir $reports_dir
file mkdir $data_dir

### initial options

### restore design
restoreDesign ${data_root}/${before_step}/${before_step}.enc.dat $design

### common optimization settings
setDesignMode -process 45
setAnalysisMode -analysisType onChipVariation -cppr both ;# OCV
setOptMode -addInstancePrefix "PRECTS_" -addNetPrefix "PRECTS_NET_"
setOptMode -powerEffort none
setTieHiLoMode -maxFanout 2 -honorDontTouch true -honorDontUse true -prefix "PRECTS_TIE_" -cell {TIEHI TIELO}
# setOptMode -maxDensity 0.95 -maxLength 500
# setPlaceMode -place_global_max_density 0.75
# setPlaceMode -place_global_cong_effort high

### routing related settings
setDesignMode -topRoutingLayer Metal9 -bottomRoutingLayer Metal1
setNanoRouteMode -routeWithTimingDriven true

### fix macros and ports
dbSet [dbGet top.insts.cell.subClass block -p2].pStatus fixed
dbSet [dbGet top.terms.name * -p].pStatus fixed

### create path groups (reg2reg, in2reg, reg2out, in2out)
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
setDontUse *DLY* true

### drv
set_interactive_constraint_modes [all_constraint_modes -active]
set_max_transition -clock_path 200 [all_clocks ] -override
set_max_transition -data_path 400 [all_clocks ] -override
set_interactive_constraint_modes {}

### uncertainty (setup)
# set_clock_uncertainty 150 [all_clocks] -setup
# place : jitter + clock skew + route correlation (si) + extra margin
# clock : jitter + route correlation (si) + extra margin
# route : jitter + extra margin
# signoff : jitter + extra margin

### run prects optimization
usr_disconnect_scan -si_term "SI" -generate_only
place_opt_design -expanded_views -out_dir ./myreports/${current_step}/innovus_placeopt -prefix "innovus_placeopt"

### add tie cells

### save design
file delete -force ${data_dir}/${current_step}.enc*
saveDesign ${data_dir}/${current_step}.enc

### reports and check
set timing_report_enable_auto_column_width true
set_table_style -no_frame_fix_width -nosplit

### exit Innovus
exit

##############################################################
# END
##############################################################
