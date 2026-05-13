##############################################################
# Description : Innovus Power Routing
# History     : Created by Yanfuti
##############################################################
#
#source scripts/00_common_initial_settings.tcl
#source scripts/yanfuti_procs.tcl
#
#### variables
#set current_step "03_innovus_powerplan"
#set before_step  "02_innovus_floorplan"
#set reports_dir "${reports_root}/${current_step}"
#set data_dir "${data_root}/${current_step}"
#file mkdir $reports_dir
#file mkdir $data_dir
#
#### restore design
#restoreDesign ${data_root}/${before_step}/${before_step}.enc.dat $design
#
### remove all existing power routing
editDelete -use {POWER} -shape {RING STRIPE FOLLOWPIN IOWIRE COREWIRE BLOCKWIRE PADRING BLOCKRING FILLWIRE FILLWIREOPC DRCFILL}

### common info
set die_area [dbGet top.fPlan.box]
set die_x0 [lindex $die_area 0 0]
set die_y0 [lindex $die_area 0 1]
set die_x1 [lindex $die_area 0 2]
set die_y1 [lindex $die_area 0 3]
set site_width  [dbGet top.fPlan.coreSite.size_x]
set site_height [dbGet top.fPlan.coreSite.size_y]

### create routing blockages for power
set rblkg_prefix "MACRO_PG_RBLKG_RAIL"
deleteRouteBlk -name $rblkg_prefix
set rblkg_extend "2.0"
set rblkg_layer  "Metal1"
foreach macro [dbGet [dbGet top.insts.cell.subClass block -p2].name] {
    deselectAll
    selectInst $macro
    set macro_box [dbGet selected.box]
    set box_x0 [lindex $macro_box 0 0]
    set box_y0 [lindex $macro_box 0 1]
    set box_x1 [lindex $macro_box 0 2]
    set box_y1 [lindex $macro_box 0 3]
    set rblkg_x0 [expr floor(($box_x0 - $rblkg_extend) / $site_width) * $site_width]
    set rblkg_x1 [expr (floor(($box_x1 + $rblkg_extend) / $site_width) + 1) * $site_width]
    set rblkg_y0 [expr floor(($box_y0 - $rblkg_extend) / $site_height) * $site_height]
    set rblkg_y1 [expr (floor(($box_y1 + $rblkg_extend) / $site_height) + 1) * $site_height]
    createRouteBlk -box [list $rblkg_x0 $rblkg_y0 $rblkg_x1 $rblkg_y1] -name $rblkg_prefix -layer $rblkg_layer -spacing 0
}

### calculate macro regions
set macro_region ""
foreach macro [dbGet [dbGet top.insts.cell.subClass block -p2].name] {
    set macro_box [dbGet [dbGet top.insts.name ${macro} -p].rHaloPoly]
    set macro_region [dbShape $macro_region OR $macro_box]
}

### create power rails (Metal1)
#setAddStripeMode -reset
#setAddStripeMode -stacked_via_bottom_layer Metal1 -stacked_via_top_layer Metal1
#addStripe -nets { VDD } -layer Metal1 -direction horizontal -width 0.120 -spacing 1.710 -set_to_set_distance 3.420 -start [expr 1.71 - 0.120 / 2.0] -stop $die_y1 -area $die_area -area_blockage $macro_region
#addStripe -nets { VSS } -layer Metal1 -direction horizontal -width 0.120 -spacing 1.710 -set_to_set_distance 3.420 -start [expr 1.71*2 - 0.120 / 2.0] -stop $die_y1 -area $die_area -area_blockage $macro_region
sroute -connect {corePin } \
    -layerChangeRange { M1(1) M(8) } \
    -corePinTarget { none } \
    -allowJogging 1 \
    -crossoverViaLayerRange { M1(1) M8(8) }\
    -nets {VDD VSS } \
    -allowLayerChange 1 \
    -targetViaLayerRange { M1(1) M8(8) }

### create power rings for memory cells {Metal8 & Metal9}
setAddRingMode -reset
deselectAll
selectInst [dbGet [dbGet top.insts.cell.subClass block -p2].name]
setAddRingMode -stacked_via_bottom_layer Metal1 -stacked_via_top_layer Metal9
addRing -nets {VDD VSS} -type block_rings -around selected -layer {top Metal9 bottom Metal9 left Metal8 right Metal8} -width {top 5 bottom 5 left 5 right 5} -spacing {top 1.25 bottom 1.25 left 1.25 right 1.25} -offset {top 5 bottom 5 left 5 right 5}
deselectAll 

### create power stripes (Metal8 and Metal9)
#editDelete -use {POWER} -shape {RING STRIPE FOLLOWPIN IOWIRE COREWIRE BLOCKWIRE PADRING BLOCKRING FILLWIRE FILLWIREOPC DRCFILL}
setAddStripeMode -reset
setAddStripeMode -break_at {block_ring} -stacked_via_bottom_layer Metal1 -stacked_via_top_layer Metal9
addStripe -nets {VDD VSS} -layer Metal9 -direction horizontal -width 5 -spacing 1.25 -set_to_set_distance 72 -start_from bottom -start_offset 40 -stop_offset 0 -block_ring_top_layer_limit Metal9 -block_ring_bottom_layer_limit Metal1

setAddStripeMode -reset
setAddStripeMode -break_at {block_ring} -stacked_via_bottom_layer Metal1 -stacked_via_top_layer Metal9
addStripe -nets {VDD VSS} -layer Metal8 -direction vertical -width 5 -spacing 1.25 -set_to_set_distance 75 -start_from left -start_offset 35 -stop_offset 0 -block_ring_top_layer_limit Metal9 -block_ring_bottom_layer_limit Metal1

### save design
file mkdir mydata/${current_step}
saveDesign mydata/${current_step}/${current_step}.enc

### reports
file mkdir myreports/${current_step}
verify_drc -limit 99999 -report myreports/${current_step}/verify_drc.rpt
verifyConnectivity -net {VDD VSS} -error 99999 -report myreports/${current_step}/verifyConnectivity.rpt
redirect -tee myreports/${current_step}/checkPlace.rpt { checkPlace }

### exit Innovus

##############################################################
# END
##############################################################
