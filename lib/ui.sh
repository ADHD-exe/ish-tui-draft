#!/bin/sh

clear_screen() {
    printf '\033[2J\033[H'
}

pause_for_enter() {
    printf '%s' "Press Enter to continue: "
    IFS= read -r _
}

read_choice() {
    target_var=$1
    IFS= read -r choice_value
    eval "$target_var=\$choice_value"
}

invalid_choice() {
    printf '%s\n' ""
    printf '%s\n' "Invalid choice."
    pause_for_enter
}
