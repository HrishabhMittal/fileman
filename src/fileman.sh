#!/usr/bin/env bash



COLOR_BORDER="\033[33m"
COLOR_RESET="\033[0m"
COLOR_DIR="\033[34m"
COLOR_EXEC="\033[32m"
COLOR_FILE="\033[37m"

HEIGHT=$(tput lines)
WIDTH=$(tput cols)
FOLDER="$(pwd)"

if [[ $# -ge 2 ]]; then
    echo "This command accepts only one optional argument. Please view the man page or use -h"
    exit 1
elif [[ -d "$1" ]]; then
    FOLDER="$(cd "$1"; pwd)"
elif [[ "$1" == "-h" ]]; then
    echo '
Usage: fileman [OPTIONS] [ARGUMENTS]

A simple interactive file management utility.

Options:
  -h            Show this help message and exit

Controls:
  up/down       Navigate in the Current menu
  left          Go up a directory
  right         Go into a directory
  s             Sort the selected directory
  q             Quit fileman

  refer to man page for details

Examples:
  fileman
  fileman -h
  fileman folder_name

Report issues at: hrishabhmittal.hm@gmail.com
'
    exit 0
fi

selected_parent_index=0
selected_child_index=0
parent_scroll=0
child_scroll=0
content_scroll=0


colorise() {
    local base="$1"
    local item="$2"
    local full="$base/$item"
    if [[ -d "$full" ]]; then
        echo -e "${COLOR_DIR}$item${COLOR_RESET}"
    elif [[ -x "$full" ]]; then
        echo -e "${COLOR_EXEC}$item${COLOR_RESET}"
    else
        echo -e "${COLOR_FILE}$item${COLOR_RESET}"
    fi
}


box() {
    local x="$1" y="$2" width="$3" height="$4"
    shift 4
    local title="$1" highlight_index="$2" scroll_index="$3" base_dir="$4"
    shift 4
    local lines=("$@")
    local inner_width=$(( width - 2 ))
    local inner_height=$(( height - 3 ))

    tput cup "$y" "$x"
    printf "${COLOR_BORDER}+"
    printf '%.0s-' $(seq $inner_width)
    printf "+${COLOR_RESET}"

    tput cup $(( y + 1 )) "$x"
    printf "${COLOR_BORDER}|${COLOR_RESET}"
    printf "%-${inner_width}.${inner_width}s" "$title"
    printf "${COLOR_BORDER}|${COLOR_RESET}"

    tput cup $(( y + 2 )) "$x"
    printf "${COLOR_BORDER}+"
    printf '%.0s-' $(seq $inner_width)
    printf "+${COLOR_RESET}"

    local i
    for (( i=0; i<inner_height; i++ )); do
        tput cup $(( y + 3 + i )) "$x"
        printf "${COLOR_BORDER}|${COLOR_RESET}"
        printf "%-${inner_width}s" " "
        printf "${COLOR_BORDER}|${COLOR_RESET}"
    done

    tput cup $(( y + height - 1 )) "$x"
    printf "${COLOR_BORDER}+"
    printf '%.0s-' $(seq $inner_width)
    printf "+${COLOR_RESET}"

    local total_lines=${#lines[@]}
    local max_scroll=$(( total_lines - inner_height ))
    (( max_scroll < 0 )) && max_scroll=0
    (( scroll_index > max_scroll )) && scroll_index=$max_scroll

    inner_height=$(( inner_height - 1 ))
    local line_num
    for (( i=0; i<inner_height && (i + scroll_index) < total_lines; i++ )); do
        line_num=$(( i + scroll_index ))
        local item="${lines[line_num]}"
        if [[ -n "$base_dir" ]]; then
            item=$(colorise "$base_dir" "$item")
        fi
        tput cup $(( y + 3 + i )) $(( x + 1 ))
        if [[ "$highlight_index" -ge 0 && "$line_num" -eq "$highlight_index" ]]; then
            tput rev
        fi
        printf "%-${inner_width}.${inner_width}s" "$item"
        tput sgr0
    done
}


get_selected_path() {
    echo "$FOLDER/${current_files[selected_child_index]}"
}


wrap_text() {
    local width=$RIGHT_WIDTH input=("$@") output=() line
    for line in "${input[@]}"; do
        if [[ -z "$line" ]]; then
            output+=( "" )
        else
            while [[ ${#line} -gt $width ]]; do
                output+=( "${line:0:$width}" )
                line="${line:$width}"
            done
            output+=( "$line" )
        fi
    done
    printf "%s\n" "${output[@]}"
}





popup() {
    if [ $# -gt 0 ]; then
        local msg="$1"
        clear
        local width=50 height=7 x=15 y=8
        box "$x" "$y" "$width" "$height" "Message" -1 0 "" "$msg"
        read -n 1 key
        echo
        if [[ "$key" == "y" || "$key" == "Y" ]]; then
            return 0
        else
            return 1
        fi
    fi
}



configused=""
configpopup() {
    local config_dir="${HOME}/.config/fileman"
    local configs=()
    for file in "$config_dir"/*; do
        [[ -f "$file" ]] && configs+=("$(basename "$file")")
    done
    configs+=("Exit")
    local selected=0 key width=40 height=10 x=10 y=5
    while true; do
        clear
        box "$x" "$y" "$width" "$height" "Select Config" "$selected" 0 "$config_dir" "${configs[@]}"
        read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                "[A") ((selected--));;
                "[B") ((selected++));;
            esac
            (( selected < 0 )) && selected=0
            (( selected >= ${#configs[@]} )) && selected=$((${#configs[@]} - 1))
        elif [[ "$key" == "" ]]; then  
            if [[ "${configs[$selected]}" == "Exit" ]]; then
                break
            else
                configused="$config_dir/${configs[$selected]}"
                break
            fi
        fi
    done
}



sortdir() {
    local target_dir="$1" config_file="$2"
    declare -A folder_map
    while IFS=":" read -r folder exts; do
        exts="$(echo $exts | sed 's/ /\n/g')"
        for ext in $exts; do
            folder_map["$ext"]="$folder"
        done
    done < "$config_file"

    for key in "${!folder_map[@]}"; do
        echo "$key: ${folder_map[$key]}"
    done
    for file in "$target_dir"/*; do
        if [[ -f "$file" ]]; then
            local filename
            filename=$(basename "$file")

            local ext
            if [[ "$filename" == *.* ]]; then
                ext="${filename##*.}"
            else
                ext="."
            fi

            if [[ -n "${folder_map[$ext]}" ]]; then
                local folder="${folder_map[$ext]}"
                mkdir -p "$target_dir/$folder"
                mv "$file" "$target_dir/$folder/"
            fi
        fi
    done
}
display() {
    HEIGHT=$(tput lines)
    WIDTH=$(tput cols)
    box_height=$(( HEIGHT - 4 ))
    FOURTH_WIDTH=$(( WIDTH / 4 ))
    HALF_WIDTH=$(( FOURTH_WIDTH * 2 ))
    RIGHT_WIDTH=$(( WIDTH - HALF_WIDTH ))
    PARENT_FOLDER="$(dirname "$FOLDER")"
    if [[ "$PARENT_FOLDER" != "$FOLDER" ]]; then
        IFS=$'\n' parent_dir=($(ls -A "$PARENT_FOLDER"))
        for i in "${!parent_dir[@]}"; do
            if [[ "${parent_dir[i]}" == "$(basename "$FOLDER")" ]]; then
                selected_parent_index="$i"
                break
            fi
        done
    else
        parent_dir=()
        selected_parent_index=0
    fi

    IFS=$'\n' current_files=($(ls -A "$FOLDER"))

    local max_scroll_parent=$(( ${#parent_dir[@]} - box_height ))
    (( max_scroll_parent < 0 )) && max_scroll_parent=0
    if (( selected_parent_index >= box_height + parent_scroll )); then
         parent_scroll=$(( selected_parent_index - box_height + 1 ))
    elif (( selected_parent_index < parent_scroll )); then
         parent_scroll=$selected_parent_index
    fi

    local max_scroll_current=$(( ${#current_files[@]} - box_height ))
    (( max_scroll_current < 0 )) && max_scroll_current=0
    if (( selected_child_index >= box_height + child_scroll )); then
         child_scroll=$(( selected_child_index - box_height + 1 ))
    elif (( selected_child_index < child_scroll )); then
         child_scroll=$selected_child_index
    fi

    box 0 0 $FOURTH_WIDTH $HEIGHT "Parent: $(basename "$PARENT_FOLDER")" "$selected_parent_index" "$parent_scroll" "$PARENT_FOLDER" "${parent_dir[@]}"
    box $FOURTH_WIDTH 0 $FOURTH_WIDTH $HEIGHT "Current: $(basename "$FOLDER")" "$selected_child_index" "$child_scroll" "$FOLDER" "${current_files[@]}"
    selected_path="$(get_selected_path)"

    if [[ -d "$selected_path" ]]; then
        IFS=$'\n' folder_contents=($(ls -A "$selected_path"))
        box $HALF_WIDTH 0 $RIGHT_WIDTH $HEIGHT "Directory: $(basename "$selected_path")" -1 "$content_scroll" "$selected_path" "${folder_contents[@]}"
    elif [[ -f "$selected_path" ]]; then
        if file "$selected_path" | grep -q "text"; then
            IFS=$'\n' raw_contents=($(cat "$selected_path"))
            wrapped_contents=()
            while IFS= read -r line; do
                wrapped_contents+=( "$line" )
            done < <(wrap_text "${raw_contents[@]}")
            box $HALF_WIDTH 0 $RIGHT_WIDTH $HEIGHT "File: $(basename "$selected_path")" -1 "$content_scroll" "" "${wrapped_contents[@]}"
        else
            box $HALF_WIDTH 0 $RIGHT_WIDTH $HEIGHT "Binary File: $(basename "$selected_path")" -1 0 "" "Non-text file"
        fi
    fi
}



input() {
    while true; do
        read -rsn1 key
        case "$key" in
            $'\x1b')
                read -rsn2 -t 0.1 key2
                case "$key2" in
                    '[A')
                        (( selected_child_index > 0 )) && (( selected_child_index-- ))
                        ;;
                    '[B')
                        (( selected_child_index < ${#current_files[@]} - 1 )) && (( selected_child_index++ ))
                        ;;
                    '[D')
                        if [[ "$PARENT_FOLDER" != "$FOLDER" ]]; then
                            FOLDER="$PARENT_FOLDER"
                            selected_child_index=0
                            child_scroll=0
                        fi
                        ;;
                    '[C')
                        selected_path="$(get_selected_path)"
                        if [[ -d "$selected_path" ]]; then
                            FOLDER="$selected_path"
                            selected_child_index=0
                            child_scroll=0
                        fi
                        ;;
                esac
                ;;
            5)
                (( content_scroll > 0 )) && (( content_scroll-- ))
                ;;
            6)
                if [[ -d "$selected_path" ]]; then
                    local cnt=${#folder_contents[@]}
                    local max=$(( cnt - box_height ))
                    (( max < 0 )) && max=0
                    (( content_scroll < max )) && (( content_scroll++ ))
                elif [[ -f "$selected_path" && $(file "$selected_path" | grep -q "text"; echo $?) -eq 0 ]]; then
                    local cnt=${#wrapped_contents[@]}
                    local max=$(( cnt - box_height ))
                    (( max < 0 )) && max=0
                    (( content_scroll < max )) && (( content_scroll++ ))
                fi
                ;;
            s)
                selected_path="$(get_selected_path)"
                if [[ -d "$selected_path" ]]; then
                    configpopup
                    if [[ "$configused" != "" ]]; then
                        sortdir "$selected_path" "$configused"
                        popup "Press any key to continue."
                    fi
                else
                    popup "Selection is not a directory. Press any key to continue."
                fi
                ;;
            q)
                exit 0
                ;;
        esac
        display
    done
}


stty -echo
tput civis
trap "stty echo; tput cnorm; clear; exit" EXIT
clear
display
input
