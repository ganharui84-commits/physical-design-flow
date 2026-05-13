##############################################################
# Common design settings
# Created by Yanfuti
##############################################################
### design information
set design "leon"

### design data directory
set data_root       "./data"
set reports_root    "./reports"

### gate level netlist files
set import_netlists     ""
lappend import_netlists "/home/EDA/Desktop/LEON/library/${design}.vnet.gz"

### SDC files

### tech lef
set tech_lef "/home/EDA/Desktop/LEON/library/lef/gsclib045_tech.lef"

### /home/EDA/Desktop/LEON files
set lef_files ""
lappend lef_files "/home/EDA/Desktop/LEON/library/lef/gsclib045_hvt_macro.lef"
lappend lef_files "/home/EDA/Desktop/LEON/library/lef/gsclib045_macro.lef"
lappend lef_files "/home/EDA/Desktop/LEON/library/lef/MEM1_256X32.lef"
lappend lef_files "/home/EDA/Desktop/LEON/library/lef/MEM2_128X32.lef"
lappend lef_files "/home/EDA/Desktop/LEON/library/lef/pdkIO.lef"
lappend lef_files "/home/EDA/Desktop/LEON/library/lef/pads.lef"

### PEX tech
set qrc_tech(rcbest)        "/home/EDA/Desktop/LEON/library/tech/qrc/rcbest/qrcTechFile"
set qrc_tech(rcworst)       "/home/EDA/Desktop/LEON/library/tech/qrc/rcworst/qrcTechFile"
set qrc_tech(typical)       "/home/EDA/Desktop/LEON/library/tech/qrc/typical/qrcTechFile"

### view (scenarios) of each step
set default_scenarios  "func_slow_rcworst"
set placeopt_scenarios "func_slow_rcworst"
set cts_scenarios      "cts_slow_rcworst"
set clockopt_scenarios "func_slow_rcworst func_fast_rcbest"
set routeopt_scenarios "func_slow_rcworst func_fast_rcbest"

### cells type settings
set fillers_ref     "FILL1 FILL16 FILL2 FILL32 FILL4 FILL64 FILL8"
set welltap_ref     "DECAP8"

##############################################################
# END
##############################################################
