##############################################################
# Description : Read Gate Level Netlist into Innovus
# History     : Created by Yanfuti
##############################################################

##source scripts/00_common_initial_settings.tcl

### variables
set current_step "01_innovus_import"
set reports_dir "${reports_root}/${current_step}"
set data_dir "${data_root}/${current_step}"
file mkdir $reports_dir
file mkdir $data_dir

### design settings
set init_top_cell $design
setImportMode -keepEmptyModule true
set init_lef_file [concat $tech_lef $lef_files]
set init_verilog $import_netlists
set init_pwr_net "VDD"
set init_gnd_net "VSS"
set init_mmmc_file "/home/EDA/Desktop/LEON/scripts/viewDefinition.tcl"

### read design
init_design
setIoFlowFlag 0

### connect pg 
globalNetConnect $init_pwr_net -type pgpin -pin VDD -all
globalNetConnect $init_gnd_net -type pgpin -pin VSS -all

### save design
file delete -force ${data_dir}/${current_step}.enc*
saveDesign ${data_dir}/${current_step}.enc

### exit Innovus
##exit

##############################################################
# End of File
##############################################################
