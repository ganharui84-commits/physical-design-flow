### /home/EDA/Desktop/LEON set (-aocv or lvf, spatial socv)
create_library_set -name "fast" -timing\
    [list \
        /home/EDA/Desktop/LEON/library/liberty/fast_vdd1v2_basicCells.lib \
        /home/EDA/Desktop/LEON/library/liberty/fast_vdd1v2_basicCells_hvt.lib \
        /home/EDA/Desktop/LEON/library/liberty/MEM1_256X32_slow.lib \
        /home/EDA/Desktop/LEON/library/liberty/MEM2_128X32_slow.lib \
    ]
create_library_set -name "slow" -timing \
    [list \
        /home/EDA/Desktop/LEON/library/liberty/slow_vdd1v0_basicCells.lib \
        /home/EDA/Desktop/LEON/library/liberty/slow_vdd1v0_basicCells_hvt.lib \
        /home/EDA/Desktop/LEON/library/liberty/MEM1_256X32_slow.lib \
        /home/EDA/Desktop/LEON/library/liberty/MEM2_128X32_slow.lib \
    ]

### rc corner
create_rc_corner -name "rc_best" \
    -preRoute_res 1.34236 \
    -postRoute_res 1.34236 \
    -preRoute_cap 1.10066 \
    -postRoute_cap 0.960235 \
    -postRoute_xcap 1.22327 \
    -preRoute_clkres 0 \
    -preRoute_clkcap 0 \
    -postRoute_clkcap {0.969117 0 0} \
    -T 0 \
    -qx_tech_file /home/EDA/Desktop/LEON/library/tech/qrc/typical/qrcTechFile
create_rc_corner -name "rc_worst" \
    -preRoute_res 1.34236 \
    -postRoute_res 1.34236 \
    -preRoute_cap 1.10066 \
    -postRoute_cap 0.960234 \
    -postRoute_xcap 1.22327 \
    -preRoute_clkres 0 \
    -preRoute_clkcap 0 \
    -postRoute_clkcap {0.969117 0 0} \
    -T 125 \
    -qx_tech_file /home/EDA/Desktop/LEON/library/tech/qrc/rcworst/qrcTechFile

### delay corner for each pvt (process voltage temperature) : /home/EDA/Desktop/LEON set + rc corner
create_delay_corner -name slow_rcworst \
    -library_set slow \
    -rc_corner rc_worst
create_delay_corner -name fast_rcbest \
    -library_set fast \
    -rc_corner rc_best

### mode : (func + shift + capture)
create_constraint_mode -name functional \
    -sdc_files [list /home/EDA/Desktop/LEON/library/leon.func.slow_rcworst.sdc.gz]

### define view (mode + delay corner)
create_analysis_view -name func_slow_rcworst -constraint_mode functional -delay_corner slow_rcworst
create_analysis_view -name func_fast_rcbest  -constraint_mode functional -delay_corner fast_rcbest

### set analysis view status
set_analysis_view -setup [list func_slow_rcworst] -hold [list func_fast_rcbest]

