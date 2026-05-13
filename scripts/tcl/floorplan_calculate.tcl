##caluate area(cells+marco)
set all_cells [dbGet top.insts]
set all_cells_area 0.0
foreach cell $all_cells {
    set cell_area [dbGet ${cell}.area]
    set all_cells_area [expr $all_cells_area + $cell_area]
}
puts " $all_cells_area um^2"
set all_macros [dbGet top.insts.cell.subClass block -p2]
set all_macros_area 0.0
foreach macrocell $all_macros {
    set macro_area [dbGet ${macrocell}.area]
    set all_macros_area [expr $all_macros_area + $macro_area]
}
puts "$all_macros_area um^2"
set all_stdcells_area [expr $all_cells_area - $all_macros_area]
puts "$all_stdcells_area um^2"
set total_estimate_area [expr $all_stdcells_area / 0.65 + $all_macros_area / 0.82]
puts "$total_estimate_area um^2"
set side_length [expr sqrt($total_estimate_area)]
puts "if squre,suggest:$side_length um" 
