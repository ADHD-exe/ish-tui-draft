#!/bin/sh

RENDER_SCOPE=${RENDER_SCOPE:-4}
RENDER_MODE=${RENDER_MODE:-1}
RENDER_BASH=${RENDER_BASH:-1}
RENDER_ZSH=${RENDER_ZSH:-1}
RENDER_FISH=${RENDER_FISH:-1}
RENDER_MARKER_BEGIN="# >>> iosish managed block >>>"
RENDER_MARKER_END="# <<< iosish managed block <<<"

module_describe() {
    printf '%s\n' "Renders aliases, environment exports, and helper snippets from the registry layer into shell startup files."
}

module_detect() {
    TARGET_USERS=$(resolve_user_scope "$RENDER_SCOPE")
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    [ "$RENDER_BASH" = "1" ] && printf '%s\n' "- render ~/.bashrc managed block"
    [ "$RENDER_ZSH" = "1" ] && printf '%s\n' "- render ~/.zshrc managed block"
    [ "$RENDER_FISH" = "1" ] && printf '%s\n' "- render ~/.config/fish/config.fish managed block"
    printf '%s\n' "- consume aliases, env, and helpers from registry files only"
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "Apply shell rendering?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Show details first"
    printf '%s' "Choose an option: "
    read_choice render_confirm_choice
    case "$render_confirm_choice" in
        1) return 0 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        3) module_plan; pause_for_enter; module_confirm; return $? ;;
        *) invalid_choice; module_confirm; return $? ;;
    esac
}

build_render_block() {
    shell_kind=$1
    printf '%s\n' "$RENDER_MARKER_BEGIN"
    if [ "$shell_kind" = "fish" ]; then
        render_fish_registry_content
    else
        if [ -f "$ENV_REGISTRY" ]; then
            cat "$ENV_REGISTRY"
        fi
        if [ -f "$ALIASES_REGISTRY" ]; then
            cat "$ALIASES_REGISTRY"
        fi
        if [ -f "$HELPERS_REGISTRY" ]; then
            cat "$HELPERS_REGISTRY"
        fi
    fi
    printf '%s\n' "$RENDER_MARKER_END"
}

render_fish_registry_content() {
    if [ -f "$ENV_REGISTRY" ]; then
        awk '
            /^export[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=/ {
                line=$0
                sub(/^export[[:space:]]+/, "", line)
                split(line, parts, "=")
                key=parts[1]
                value=line
                sub(/^[^=]*=/, "", value)
                gsub(/^"/, "", value)
                gsub(/"$/, "", value)
                print "set -gx " key " \"" value "\""
                next
            }
            { print "# unsupported env entry for fish: " $0 }
        ' "$ENV_REGISTRY"
    fi

    if [ -f "$ALIASES_REGISTRY" ]; then
        awk '
            /^alias[[:space:]]+[A-Za-z0-9_-]+='\''.*'\''$/ {
                line=$0
                sub(/^alias[[:space:]]+/, "", line)
                name=line
                sub(/=.*/, "", name)
                value=line
                sub(/^[^=]*='\''/, "", value)
                sub(/'\''$/, "", value)
                print "alias " name "=\"" value "\""
                next
            }
            { print "# unsupported alias entry for fish: " $0 }
        ' "$ALIASES_REGISTRY"
    fi

    if [ -f "$HELPERS_REGISTRY" ]; then
        while IFS= read -r helper_line; do
            [ -n "$helper_line" ] || continue
            printf '%s\n' "# helper not rendered for fish: $helper_line"
        done < "$HELPERS_REGISTRY"
    fi
}

render_managed_block() {
    target_path=$1
    shell_kind=$2
    tmp_file="${TMPDIR:-/tmp}/ish-tui-render.$$"
    managed_file="${TMPDIR:-/tmp}/ish-tui-render-block.$$"

    build_render_block "$shell_kind" > "$managed_file"
    ensure_parent_dir "$target_path"

    if [ -f "$target_path" ]; then
        awk -v begin="$RENDER_MARKER_BEGIN" -v end="$RENDER_MARKER_END" '
            $0 == begin { skip=1; next }
            $0 == end { skip=0; next }
            !skip { print }
        ' "$target_path" > "$tmp_file"
        printf '\n' >> "$tmp_file"
        cat "$managed_file" >> "$tmp_file"
    else
        cat "$managed_file" > "$tmp_file"
    fi

    if [ -f "$target_path" ] && cmp -s "$tmp_file" "$target_path"; then
        rm -f "$tmp_file" "$managed_file"
        return 0
    fi

    backup_file "$target_path"
    mv "$tmp_file" "$target_path"
    rm -f "$managed_file"
}

module_apply() {
    printf '%s\n' "$TARGET_USERS" | while IFS=: read -r _role _user home_path; do
        [ -n "$home_path" ] || continue
        [ "$RENDER_BASH" = "1" ] && render_managed_block "$home_path/.bashrc" "sh"
        [ "$RENDER_ZSH" = "1" ] && render_managed_block "$home_path/.zshrc" "sh"
        if [ "$RENDER_FISH" = "1" ]; then
            mkdir -p "$home_path/.config/fish" 2>/dev/null || true
            render_managed_block "$home_path/.config/fish/config.fish" "fish"
        fi
    done
    return 0
}

module_validate() {
    printf '%s\n' "$TARGET_USERS" | while IFS=: read -r _r _u h; do
        [ -n "$h" ] || continue
        if [ "$RENDER_BASH" = "1" ]; then
            validate_file_exists "$h/.bashrc" || return 1
        fi
        if [ "$RENDER_ZSH" = "1" ]; then
            validate_file_exists "$h/.zshrc" || return 1
        fi
        if [ "$RENDER_FISH" = "1" ]; then
            validate_file_exists "$h/.config/fish/config.fish" || return 1
        fi
    done || return 1
    return 0
}

module_save_state() {
    state_set "$STATE_FEATURES_FILE" "render.scope" "$RENDER_SCOPE"
    state_set "$STATE_FEATURES_FILE" "render.bash" "$RENDER_BASH"
    state_set "$STATE_FEATURES_FILE" "render.zsh" "$RENDER_ZSH"
    state_set "$STATE_FEATURES_FILE" "render.fish" "$RENDER_FISH"
    state_set "$STATE_FEATURES_FILE" "render.status" "complete"
    return 0
}

module_configure() {
    pause_for_enter
}
