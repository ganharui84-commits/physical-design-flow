##############################################################
# Description : Initialize Floorplan in Innovus
# History     : Created by Yanfuti
##############################################################

source scripts/00_common_initial_settings.tcl
source scripts/yanfuti_procs.tcl

### variables
set current_step "02_innovus_floorplan"
set before_step  "01_innovus_import"

### restore design
restoreDesign data/${before_step}/${before_step}.enc.dat $design

### initialize shape
# -d <W H Left Bottom Right Top>          # by DIE size and core to edge (list, required)
#floorPlan -d 1000 800.28 1.0 1.71 1.0 1.71
floorPlan -site CoreSite -d 930 600.28 0 1.71 0 1.71 -fplanOrigin llcorner
#
## -s <W H Left Bottom Right Top>          # by core size and core to edge (list, required)
#floorPlan -s 1000 800.28 1.0 1.71 1.0 1.71
#
## -fplanOrigin {center llcorner}
#floorPlan -s 1000 800.28 1.0 1.71 1.0 1.71 -fplanOrigin llcorner
#floorPlan -s 1000 800.28 1.0 1.71 1.0 1.71 -fplanOrigin center
#
## rectilinear (polygon)
#setPreference EnableRectilinearDesign 1
#setObjFPlanPolygon Cell $design 0.0 0.0 0.0 800.28 1000.0 800.28 1000.0 422.37 538.8 422.37 538.8 0.0

# report utilization

### create tracks (optional)

### create rows (optional)

### place hard macros
source scripts/place_hard_macros.tcl

### create placement and routing halo around hard macros (instance name vs cell name, and reference name)
set halo_left   2.0
set halo_right  2.0
set halo_top    2.0
set halo_bottom 2.0
set rhalo_space 2.0
deleteHaloFromBlock -allBlock 
deleteRoutingHalo -allBlocks
#addHaloToBlock $halo_left $halo_bottom $halo_right $halo_top -allBlock
foreach macro [dbGet [dbGet top.insts.cell.subClass block -p2].name] {
    addHaloToBlock $halo_left $halo_bottom $halo_right $halo_top $macro
    addRoutingHalo -space $rhalo_space -top Metal11 -bottom Metal1 -inst $macro
}

### place ports
set input_ports [dbGet [dbGet top.terms.direction input -p].name]
editPin -pinWidth 0.08 -pinDepth 0.32 -fixOverlap 1 -unit TRACK -spreadDirection clockwise -layer 5 -spreadType start -spacing 2 -start 0 220 -pin $input_ports -fixedPin -side LEFT
set output_ports [dbGet [dbGet top.terms.direction output -p].name]
editPin -pinWidth 0.08 -pinDepth 0.32 -fixOverlap 1 -unit TRACK -spreadDirection counterclockwise -layer 5 -spreadType start -spacing 2 -start 0 170 -pin $output_ports -fixedPin -side RIGHT
dbSet top.terms.pStatus fixed

### create placement blockages (hard, soft and partial)
# hard : no cells should be placed in hard blockages
# soft : only buffers and inverters are allowed
# partial : only allowed with specified max density
createPlaceBlockage -type soft -density 50 -name pblkg_top -box {0.0000000000 1.7100000000 930.0000000000 174.4200000000}
createPlaceBlockage -type soft -density 50 -name pblkg_bot -box {0.0000000000 420.6600000000 930.0000000000 598.5000000000}

### create routing blockage (optional)

### insert boundary cells (endcap)
set endcap_prefix   "ENDCAP"
set endcap_left     "FILL2"
set endcap_right    "FILL2"
set endcap_top      "FILL1"
set endcap_bottom   "FILL1"

deleteFiller -prefix $endcap_prefix
setEndCapMode -reset
setEndCapMode -topEdge $endcap_top
setEndCapMode -bottomEdge $endcap_bottom
setEndCapMode -leftEdge $endcap_left
setEndCapMode -rightEdge $endcap_left

setEndCapMode -leftBottomCorner $endcap_bottom
setEndCapMode -leftTopCorner $endcap_top
setEndCapMode -rightBottomCorner $endcap_bottom
setEndCapMode -rightTopCorner $endcap_top

setEndCapMode -leftBottomEdge $endcap_left
setEndCapMode -leftTopEdge $endcap_left
setEndCapMode -rightBottomEdge $endcap_right
setEndCapMode -rightTopEdge $endcap_right
addEndCap -prefix $endcap_prefix

### create well tap cells (fix latch up)
set welltap_prefix   "WELLTAP"
deleteFiller -prefix $welltap_prefix
addWellTap -prefix $welltap_prefix -cell $welltap_ref -cellInterval 70 -checkerBoard

### save design
file delete -force ${data_dir}/${current_step}.enc*
saveDesign ${data_dir}/${current_step}.enc

##############################################################
# END
##############################################################
