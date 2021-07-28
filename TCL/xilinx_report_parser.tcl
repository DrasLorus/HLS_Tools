#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" ${1+"$@"}

#
# Copyright© 2021 Camille 'DrasLorus' Monière
# <draslorus@draslorus.fr>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

package require tdom

namespace eval XilinxRptParser {

  variable PATH_IMPL "impl/report/verilog"
  variable SUFFIX_IMPL "_export.xml"
  variable PATH_HLS "syn/report/csynth.xml"

  variable allSolutions ""
  variable nSolutions 0

  variable hlsHeaders [list \
    "unit" \
    "Best-caseLatency" \
    "Average-caseLatency" \
    "Worst-caseLatency" \
    "Best-caseRealTimeLatency" \
    "Average-caseRealTimeLatency" \
    "Worst-caseRealTimeLatency" \
    "Interval-min" \
    "Interval-max"]

  variable fileHlsHeaders [list \
    "unit" \
    "BestLat" \
    "AvrgLat" \
    "WrstLat" \
    "BestRT" \
    "AvrgRT" \
    "WrstRT" \
    "IIMin" \
    "IIMax"]

  variable resultTextFile "./parsed_reports.txt"

  variable formatHlsHead "%14s %8s %8s %8s %10s %10s %10s %8s %8s "
  variable formatHls "%14s %8u %8u %8u %10s %10s %10s %8u %8u "

  variable projectPath "/home/moniere/Downloads/qcsp_emitter"

  proc puts_error_value {columnLength fileDescriptor} {
    puts $fileDescriptor [format "%${columnLength}d" "-1"]
  }

  proc get_all_solutions {} {
    variable projectPath

    variable allSolutions
    set allSolutions [ glob -directory $projectPath -tails -type d * ]

    variable nSolutions
    set nSolutions [ llength $allSolutions ]

    set allSolutions
  }

  # Create outFIle if it does not exist or erase it if it does.
  # Then writes "id", first column header.
  proc create_txt_report { outFile } {

    set fid [open $outFile "w"]

    variable projectPath
    variable nSolutions
    variable PATH_HLS
    variable allSolutions

    set id_digits [ expr {
      [ ::tcl::mathfunc::int [ ::tcl::mathfunc::log10 $nSolutions ] ] + 1
    } ]


    set totalPath $projectPath/[lindex $allSolutions 1]/$PATH_HLS
    puts -nonewline $fid [format "%${id_digits}s" "id"]

    close $fid
  }

  # Append the headers for HLS synthesis in outfile
  proc write_header_hls { outFile } {

    set fid [open $outFile "a"]

    variable PATH_IMPL
    variable SUFFIX_IMPL
    variable PATH_HLS

    variable projectPath "/home/moniere/Downloads/qcsp_emitter"
    variable resultTextFile
    variable nSolutions
    variable allSolutions
    variable formatHlsHead

    puts -nonewline $fid [format $formatHlsHead $fileHlsHeaders]

    # Open XML report and parse it using TDom
    set xmlf [open $totalPath RDONLY]
    set XML [read $xmlf]
    close $xmlf
    set doc [dom parse $XML]

    set root [$doc documentElement]

    ## Since Xilinx reports are not consistent, can't simply extract the headers
    # variable hlsHeaders
    # set nodes [$root selectNodes /*/PerformanceEstimates/SummaryOfOverallLatency/*]
    # set hlsHeaders ""
    # foreach node $nodes {
    #   lappend hlsHeaders [$node nodeName]
    # }
    close $fid
  }

  # Append the last column header "arch" in outFile and end the header line
  proc end_header { outFile } {
    set fid [open $outFile "a"]
    puts $fid "arch"
    close $fid
  }

  proc parse_hls_reports { outFile } {
    set fid [open $outFile "a"]

    set solIdx 0
    foreach solution $allSolutions {

      incr $solIdx
    }

    close $fid
  }



}