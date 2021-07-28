#! /bin/bash

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

TEMP=$(getopt --shell bash -o 'p:t:o:as' --long 'project-path:,report-type:,output:,all,separated' -n 'xilinx_parser.bash' -- "$@")

if [ "$?" -ne 0 ]; then
  echo 'Terminating...' >&2
  exit 1
fi

# Note the quotes around "$TEMP": they are essential!
eval set -- "$TEMP"
unset TEMP

PROJECT_PATH=""
declare -a TYPES=("sim" "hls" "syn" "impl")
declare -A REPORT_TYPE
for type in "${TYPES[@]}"; do
  REPORT_TYPE[$type]=0
done

declare -ga HLS_HEADERS
HLS_HEADERS=(
  "unit"
  "Best-caseLatency"
  "Average-caseLatency"
  "Worst-caseLatency"
  "Best-caseRealTimeLatency"
  "Average-caseRealTimeLatency"
  "Worst-caseRealTimeLatency"
  "Interval-min"
  "Interval-max"
)
## Since Xilinx reports are not consistent, can't simply extract the headers 
# readarray -t HLS_HEADERS \
#   <<<"$(xmllint --shell "qcsp_emitter/${ALL_SOLUTION[0]}/$PATH_HLS" \
#     <<<'du /*/PerformanceEstimates/SummaryOfOverallLatency/*' |
#     grep -v '>')"

PATH_IMPL="impl/report/verilog"
SUFFIX_IMPL="_export.xml"
PATH_HLS="syn/report/csynth.xml"

RESULT_TEXT_FILE=""
declare -i SOLUTION_IDX=0
declare -i SEPARATED=0

while true; do
  case "$1" in
  '-s' | '--separated')
    if [[ -n $SEPARATED ]]; then
      echo 'ERROR: separated flags specified multiple times' >&2
      exit 1
    fi
    SEPARATED=1
    shift
    continue
    ;;
  '-p' | '--project-path')
    if [[ -n $PROJECT_PATH ]]; then
      echo 'ERROR: Cannot process multiple project path.' >&2
      exit 1
    fi

    echo "Project at $2"
    PROJECT_PATH="$2"
    declare -g PROJECT_NAME
    PROJECT_NAME=$(basename "$PROJECT_PATH")
    shift 2
    continue
    ;;
  '-o' | '--output')
    if [[ -n $RESULT_TEXT_FILE ]]; then
      echo 'ERROR: Cannot output to multiple files.' >&2
      exit 1
    fi

    RESULT_TEXT_FILE=$2
    shift 2
    continue
    ;;
  '-t' | '--report-type')
    declare -a TMP
    IFS=',' read -ra TMP <<<"$2"

    if ((${#TYPES[@]} < ${#TMP[@]})); then
      echo 'ERROR: Too many report types given. Expected at most '${#TYPES[@]}' and got '${#TMP[@]}'.' >&2
      exit 1
    fi

    for fl in "${TMP[@]}"; do
      if ((REPORT_TYPE[$fl] == 1)); then
        echo "ERROR: $fl specified multiple times." >&2
        exit 1
      elif [[ "${TYPES[*]}" =~ '(^| )'"$fl"'( |$)' ]]; then
        echo "ERROR: type $fl does not exist. Possible types: ${TYPES[*]}"
        exit 1
      fi
      REPORT_TYPE[$fl]=1
    done

    shift 2
    unset TMP
    continue
    ;;
  '-a' | '--all')
    SOLUTION_IDX=-1
    shift
    continue
    ;;
  '--')
    shift
    break
    ;;
  *)
    echo 'Internal error!' >&2
    exit 1
    ;;
  esac
done

if [ "$RESULT_TEXT_FILE" = "" ]; then
  RESULT_TEXT_FILE="./parsed_reports.txt"
fi

if [ "$PROJECT_PATH" = "" ]; then
  echo 'ERROR: a project path must be specified.' >&2
  exit 1
fi

declare -a ALL_SOLUTION
# echo "$SOLUTION_IDX"

# echo "ls -d "$PROJECT_PATH/*/"  | sort -"
if ((SOLUTION_IDX == -1)); then
  SOLUTION_IDX=$((SOLUTION_IDX + 1))
  tmp="$(find "$PROJECT_PATH" -maxdepth 1 -type d -not -name "$PROJECT_NAME" -not -name '*.*' -exec basename {} \;)"
  for sol in $tmp; do
    ALL_SOLUTION[$SOLUTION_IDX]="$sol"
    SOLUTION_IDX=$((SOLUTION_IDX + 1))
  done
  unset tmp
else
  while (($# != 0)); do
    # echo "$SOLUTION_IDX"
    # echo "${ALL_SOLUTION[@]}"

    ALL_SOLUTION[$SOLUTION_IDX]="$1"
    SOLUTION_IDX=$((SOLUTION_IDX + 1))
    shift

    # echo "$SOLUTION_IDX"
    # echo "${ALL_SOLUTION[@]}"
  done
fi

if ((SOLUTION_IDX == 0)); then
  echo "ERROR: no solution specified."
  exit 1
fi

declare -i SUMT=0
for rt in "${REPORT_TYPE[@]}"; do
  SUMT=$((SUMT + rt))
done
if ((SUMT == 0)); then
  echo "ERROR: need at least one report type."
  exit 1
fi

function write_header() {

  if [ "$#" != "1" ]; then
    echo "ERROR: write_header takes exactly $((${#TYPES[@]} + 1)) argument."
    return 1
  fi

  OFILE="$1"
  shift

  printf "%2s " "id" >>"$OFILE"

  for rt in "${TYPES[@]}"; do
    if [ "${REPORT_TYPE[$rt]}" = "1" ]; then
      case "$rt" in
      'impl')
        TOP_NAME="$(xmllint --xpath 'string(//TopModelName)' "$PROJECT_PATH/${ALL_SOLUTION[0]}/$PATH_HLS")"
        declare -ga IMPL_RESOURCES_HEAD
        readarray -t IMPL_RESOURCES_HEAD <<<"$(xmllint --shell "$PROJECT_PATH/${ALL_SOLUTION[0]}/$PATH_IMPL/$TOP_NAME$SUFFIX_IMPL" <<<'du profile/AreaReport/Resources/*' | grep -v '>')"
        declare -ga IMPL_AVAILRES_HEAD
        readarray -t IMPL_AVAILRES_HEAD <<<"$(xmllint --shell "$PROJECT_PATH/${ALL_SOLUTION[0]}/$PATH_IMPL/$TOP_NAME$SUFFIX_IMPL" <<<'du profile/AreaReport/AvailableResources/*' | grep -v '>')"
        declare -ga IMPL_TIMING_HEAD
        readarray -t IMPL_TIMING_HEAD <<<"$(xmllint --shell "$PROJECT_PATH/${ALL_SOLUTION[0]}/$PATH_IMPL/$TOP_NAME$SUFFIX_IMPL" <<<'du profile/TimingReport/*' | grep -v '>')"

        for rec in "${IMPL_RESOURCES_HEAD[@]}"; do
          printf "%7s " "${rec/\n/}" >>"$OFILE"
        done

        for rec in "${IMPL_AVAILRES_HEAD[@]}"; do
          printf "%10s " "${rec/\n/}_avlb" >>"$OFILE"
        done

        for rec in "${IMPL_AVAILRES_HEAD[@]}"; do
          printf "%9s " "${rec/\n/}_prc" >>"$OFILE"
        done

        # for tim in "${IMPL_TIMING_HEAD[@]}"; do
        #     printf "%7s " "${tim/\n/}" >>"$1"
        # done
        printf "%5s %5s " "TCP" "ACP" >>"$OFILE"

        printf "%5s %s " "Slack" "arch" >>"$OFILE"
        continue
        ;;

      'hls')
        printf "%14s %8s %8s %8s %10s %10s %10s %8s %8s " \
          "unit" "BestLat" "AvrgLat" "WrstLat" "BestRT" \
          "AvrgRT" "WrstRT" "IIMin" "IIMax" >>"$OFILE"
        continue
        ;;

      # 'sim')
      #   shift
      #   continue
      #   ;;

      *)
        echo "ERROR: type $1 not support (yet?)." >&2
        exit 1
        ;;
      esac
    fi
  done
  printf "\n" >>"$OFILE"
  return 0
}

# take solution return array of value
function parse_solutions() {
  i=0

  for solution in "${ALL_SOLUTION[@]}"; do

    printf "%2d " "$i" >>"$1"

    for rt in "${TYPES[@]}"; do
      if [ "${REPORT_TYPE[$rt]}" = "1" ]; then
        case $rt in
        'impl')
          TOP_NAME="$(xmllint --xpath 'string(//TopModelName)' "$PROJECT_PATH/${ALL_SOLUTION[0]}/$PATH_HLS")"
          for res in "${IMPL_RESOURCES_HEAD[@]}"; do
            value="$(
              xmllint --xpath "string(//Resources/$res)" \
                "$PROJECT_PATH/$solution/$PATH_IMPL/$TOP_NAME$SUFFIX_IMPL" 2>/dev/null
            )"
            if [[ -z $value ]]; then
              printf "%7s " "-1" >>"$1"
            else
              printf "%7d " "$value" >>"$1"
            fi
          done

          for res in "${IMPL_AVAILRES_HEAD[@]}"; do
            value="$(xmllint --xpath "string(//AvailableResources/$res)" \
              "$PROJECT_PATH/$solution/$PATH_IMPL/$TOP_NAME$SUFFIX_IMPL" 2>/dev/null)"
            if [[ -z $value ]]; then
              printf "%10s " "-1" >>"$1"
            else
              printf "%10d " "$value" >>"$1"
            fi
          done

          for res in "${IMPL_AVAILRES_HEAD[@]}"; do
            value="$(xmllint --xpath "string(//Resources/$res * 100.0 div //AvailableResources/$res)" \
              "$PROJECT_PATH/$solution/$PATH_IMPL/$TOP_NAME$SUFFIX_IMPL" 2>/dev/null)"
            if [[ -z $value ]]; then
              printf "%9s " "-1" >>"$1"
            else
              printf "%9.2f " "$value" >>"$1"
            fi
          done

          for tim in "${IMPL_TIMING_HEAD[@]}"; do
            value="$(xmllint --xpath "string(//TimingReport/$tim)" \
              "$PROJECT_PATH/$solution/$PATH_IMPL/$TOP_NAME$SUFFIX_IMPL" 2>/dev/null)"
            if [[ -z $value ]]; then
              printf "%5s " "-1" >>"$1"
            else
              printf "%5.2f " "$value" >>"$1"
            fi
          done

          value="$(xmllint --xpath "string(//TimingReport/${IMPL_TIMING_HEAD[0]} - //TimingReport/${IMPL_TIMING_HEAD[1]})" \
            "$PROJECT_PATH/$solution/$PATH_IMPL/$TOP_NAME$SUFFIX_IMPL" 2>/dev/null)"
          if [[ -z $value ]]; then
            printf "%5s " "-1" >>"$1"
          else
            printf "%5.2f " "$value" >>"$1"
          fi
          continue
          ;;
        'hls')
          for val in "${HLS_HEADERS[@]}"; do
            value="$(
              xmllint --xpath "string(/profile/PerformanceEstimates/SummaryOfOverallLatency/$val)" \
                "$PROJECT_PATH/$solution/$PATH_HLS" 2>/dev/null
            )"
            if [ "$val" = "unit" ]; then
              if [[ -z $value ]]; then
                printf "%14s " "-1" >>"$1"
              else
                printf "%14s " "$value" >>"$1"
              fi
            elif [ "$val" = "Average-caseRealTimeLatency" ] || [ "$val" = "Worst-caseRealTimeLatency" ] || [ "$val" = "Best-caseRealTimeLatency" ]; then
              if [[ -z $value ]]; then
                printf "%10s " "-1" >>"$1"
              else
                printf "%10s " "$value" >>"$1"
              fi
            else
              if [[ -z $value ]]; then
                printf "%8s " "-1" >>"$1"
              else
                printf "%8d " "$value" >>"$1"
              fi
            fi
          done

          continue
          ;;
        *)
          echo "ERROR: not supported (yet?)." >&2
          exit 1
          ;;
        esac
      fi
    done

    echo -en "$solution\n" >>"$1"
    i=$((i + 1))
  done
  return 0
}

rm -vf $RESULT_TEXT_FILE
write_header $RESULT_TEXT_FILE
parse_solutions $RESULT_TEXT_FILE
