#!/bin/bash

# Catppuccin Mocha palette colors (RGB values)
declare -a colors=(
    "243 139 168"  # Pink
    "250 179 135"  # Peach
    "249 226 175"  # Yellow
    "166 227 161"  # Green
    "148 226 213"  # Teal
    "137 220 235"  # Sky
    "116 199 236"  # Blue
    "198 160 246"  # Mauve
)

# Function to apply gradient
catppuccin_gradient() {
    local input="$1"
    local line_count=$(echo "$input" | wc -l)
    local color_count=${#colors[@]}
    local line_num=0

    while IFS= read -r line; do
        local color_index=$((line_num * color_count / line_count))
        if [ $color_index -ge $color_count ]; then
            color_index=$((color_count - 1))
        fi

        local rgb=(${colors[$color_index]})
        printf "\033[38;2;%d;%d;%dm%s\033[0m\n" "${rgb[0]}" "${rgb[1]}" "${rgb[2]}" "$line"
        ((line_num++))
    done <<< "$input"
}

# Read from stdin or file
if [ $# -eq 0 ]; then
    input=$(cat)
else
    input=$(cat "$1")
fi

catppuccin_gradient "$input"
