##############################################################
# Description : Procs for Innovus
# History     : Created by Yanfuti
##############################################################

### generate script to disconnect scan connection in Innovus
proc usr_disconnect_scan { args } {     proc定义usr_disconnect_scan函数{args}即允许用户在调用这个usr....函数时后面跟上任意数量任意格式的参数，即会把敲在这个函数后面的所有内容打包成一个list，塞进名叫args的变量里，等待函数内部去处理
    set pargs(-si_term)         "SI"  若用户未特别指定，那么扫描引脚的名字默认是 ”SI“
    set pargs(-output_script)   "detach_scan_term.tcl"    若用户未特别指定，则生成的断线脚本默认是 “detach_scan_trem.tcl"
    ##这两行是防御性编程，先给好默认值，防止用户什么参数不给导致程序崩溃
    parse_proc_arguments -args $args pargs     parse_proc_arguments是专门用来解析参数的工具函数，若用户输入-si_term "SCAN_IN"，它会去修改pargs数组，把里面的"SI"覆盖成"SCAN_IN",若用户没提 -output_script，它会保留pargs里原来的"detach_scan_term.tcl"不动，若用户输入无法定义的参数（例如 -abc 123)，该解析器通常会自动报错，提示用户“非法参数”
    ##若在终端敲下usr_disconnect_scan -si_term "SE"
    #1,{args}接收到了列表："-si_term" "SE"
    #2,set pargs 写下默认值：si_term是SI，脚本名是detach_scan_term.tcl
    #3，parse_proc_arguments 拿用户的输入和默认值对比，发现用户想覆盖引脚名，于是把内部的si_term更新为se
    #4，接下来在这个proc真正的干活代码里，它就会去寻找名为SE的引脚，并把结果输出到默认的detach_scan_term.tcl文件中。
    set op [open $pargs(-output_script) w]
    foreach inst_ptr [dbGet top.insts.instTerms.name */$pargs(-si_term) -p] {
        set inst_name [dbGet $inst_ptr.inst.name]
        set net_name [dbGet $inst_ptr.net.name]
        if {$net_name == "0x0"} {continue}
        puts $op "detachTerm $inst_name $pargs(-si_term) $net_name"  
    }
    close $op
    ##1，set op [open $pargs(-output_script) w] 这里的w代表write(写入模式)。它打开了第一段代码中设定的默认文件(detach_scan_term.tcl)
    #    ...
    #    close $op
    ##即把打开的文件句柄存给变量op (output pointer) 最后一行关掉并保存这个文件
    ##2，dbGet数据库查询
    #关于foreach inst_ptr [dbGet top.insts.instTerms.name */$pargs(-si_term) -p]的详解
    #1,top.insts.instTerms.name 为层级查找路径，工具从最顶层（top）开始，进入所有实例化的小模块/标准单元（insts），去看它们的每一个引脚（instTerms），然后查它们的引脚名子（name）
    #2，*/$pargs(si_term) 是查找条件。结合上一段的默认值，它实际上就是在找*/SI（任何名字叫SI的引脚）
    #3， -p代表point（指针），如果不加-p，工具只会返回一堆"SI SI"的字符串。加上-p后，工具返回的这些引脚在内存里的真实物理地址（指针）
    #4，foreach inst_ptr：把找出来的成千上万个引脚指针装进一个循环里，挨个处理。
    ##3，提取信息与"防呆"过滤
    #进入循环后，针对每一个找到的SI引脚指针（inst_ptr),开始套报情报：
    #1，
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
