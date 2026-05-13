##############################################################
# Description : Run Chip Finish in Innovus
# History     : Created by Yanfuti
##############################################################

source scripts/00_common_initial_settings.tcl
source scripts/yanfuti_procs.tcl

### variables
set current_step "09_innovus_chipfinish"
set before_step  "08_innovus_routeopt"
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

### common optimization settings
setDesignMode -process 45
setAnalysisMode -analysisType onChipVariation -cppr both
setTieHiLoMode -maxFanout 2 -honorDontTouch true -honorDontUse true -prefix "CHIPFINISH_TIE_" -cell {TIEHI TIELO}

### ndr (Non-Default Rule) and route types
add_ndr -width {Metal1 0.12 Metal2 0.14 Metal3 0.14 Metal4 0.14 Metal5 0.14 Metal6 0.14 Metal7 0.14 Metal8 0.14 Metal9 0.14 } -spacing {Metal1 0.12 Metal2 0.14 Metal3 0.14 Metal4 0.14 Metal5 0.14 Metal6 0.14 Metal7 0.14 Metal8 0.14 Metal9 0.14 } -name cts_2w2s
# create_route_type -name cts_route -non_default_rule cts_2w2s -bottom_preferred_layer Metal5 -top_preferred_layer Metal8
## net type : top trunk leaf
set_ccopt_property route_type cts_route -net_type trunk 
set_ccopt_property route_type cts_route -net_type top

### routing related settings
setDesignMode -topRoutingLayer Metal9 -bottomRoutingLayer Metal1
setNanoRouteMode -routeWithTimingDriven true
setNanoRouteMode -routeWithSiDriven true
setNanoRouteMode -routeWithLithoDriven true ;# DFM redundant via insertion
setNanoRouteMode -drouteFixAntenna true -routeInsertAntennaDiode true
setNanoRouteMode -routeAntennaCellName "ANTENNA" -routeAddAntennaInstPrefix "ROUTEOPT_ANT_"

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

### insert fillers (fillers, decap/gafiller (gate-array) to fix dynamic IR Drop & ECO, cut_metal/passive fill)
setFillerMode -fitGap true -add_fillers_with_drc true
setFillerMode -core $fillers_ref -corePrefix "FILLER_"
addFiller 

### save design
file delete -force ${data_dir}/${current_step}.enc*
saveDesign ${data_dir}/${current_step}.enc

### write out data
# def (rc extraction : Quantus RC, StarRC, PT)
defOut data/$current_step/${design}.${current_step}.def.gz -floorplan -netlist -routing -withShield
# netlist (formality, LEC, PT, PV LVS)
set phyonly_ref [lsort -u [dbGet [dbGet top.insts.isPhysOnly 1 -p].cell.name]]
saveNetlist -module $design -excludeCellInst $phyonly_ref data/$current_step/${design}.${current_step}.vnet.gz
saveNetlist -phys -exportTopPGNets -excludeCellInst $phyonly_ref data/$current_step/${design}.${current_step}.vnet.lvs.gz
# gds/oasis (PV : Calibre, ICV)

### reports and check

### exit Innovus
exit

##############################################################
# END
##############################################################
