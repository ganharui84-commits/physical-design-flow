##############################################################
# Description : Procs for Innovus
# History     : Created by Yanfuti
##############################################################

### generate script to disconnect scan connection in Innovus
proc usr_disconnect_scan { args } {
    set pargs(-si_term)         "SI"
    set pargs(-output_script)   "detach_scan_term.tcl"
    parse_proc_arguments -args $args pargs

    set op [open $pargs(-output_script) w]
    foreach inst_ptr [dbGet top.insts.instTerms.name */$pargs(-si_term) -p] {
        set inst_name [dbGet $inst_ptr.inst.name]
        set net_name [dbGet $inst_ptr.net.name]
        if {$net_name == "0x0"} {continue}
        puts $op "detachTerm $inst_name $pargs(-si_term) $net_name"  
    }
    close $op
    if { [info exists pargs(-generate_only)] } {
        puts "CDF-Information: Please source the created file $pargs(-output_script)"
    } else {
        source $pargs(-output_script)
        file delete -force $pargs(-output_script)
    }
}
define_proc_arguments usr_disconnect_scan \
    -info "set uncertainty for each design step" \
    -define_args {
        {-si_term           "SI term name for scan DFF, default is SI" "" string optional}
        {-output_script     "scenario name" "" string optional}
        {-generate_only     "generate script only, no execution" "" boolean optional}
}

##############################################################
# END
##############################################################
