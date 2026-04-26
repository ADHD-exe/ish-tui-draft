#!/bin/sh

DOCS_INSTALL_MANDOC=${DOCS_INSTALL_MANDOC:-1}
DOCS_INSTALL_MAN_PAGES=${DOCS_INSTALL_MAN_PAGES:-1}
DOCS_APROPOS_DB=${DOCS_APROPOS_DB:-2}
DOCS_ADD_ALIAS=${DOCS_ADD_ALIAS:-1}

module_describe() {
    printf '%s\n' "Installs man-page tooling and optional helper aliases through the registry system."
}

module_detect() {
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    [ "$DOCS_INSTALL_MANDOC" = "1" ] && printf '%s\n' "- install mandoc"
    [ "$DOCS_INSTALL_MAN_PAGES" = "1" ] && printf '%s\n' "- install man-pages"
    [ "$DOCS_APROPOS_DB" = "1" ] && printf '%s\n' "- build apropos/search database when supported"
    [ "$DOCS_ADD_ALIAS" = "1" ] && printf '%s\n' "- add docs helper aliases to registry"
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "Apply docs setup?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Show details first"
    printf '%s' "Choose an option: "
    read_choice docs_confirm_choice
    case "$docs_confirm_choice" in
        1) return 0 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        3) module_plan; pause_for_enter; module_confirm; return $? ;;
        *) invalid_choice; module_confirm; return $? ;;
    esac
}

module_apply() {
    if [ "$DOCS_INSTALL_MANDOC" = "1" ]; then
        apk_add_if_missing mandoc || true
    fi
    if [ "$DOCS_INSTALL_MAN_PAGES" = "1" ]; then
        apk_add_if_missing man-pages || true
    fi
    if [ "$DOCS_APROPOS_DB" = "1" ]; then
        if command -v makewhatis >/dev/null 2>&1; then
            makewhatis >/dev/null 2>&1 || true
        fi
    fi
    if [ "$DOCS_ADD_ALIAS" = "1" ]; then
        registry_alias_set "alias mansearch='apropos'"
        registry_alias_set "alias apkdoc='apk info -L'"
    fi
    return 0
}

module_validate() {
    [ "$DOCS_INSTALL_MANDOC" = "1" ] && apk_package_installed mandoc || true
    return 0
}

module_save_state() {
    state_set "$STATE_PACKAGES_FILE" "docs.mandoc" "$DOCS_INSTALL_MANDOC"
    state_set "$STATE_PACKAGES_FILE" "docs.man_pages" "$DOCS_INSTALL_MAN_PAGES"
    state_set "$STATE_PACKAGES_FILE" "docs.apropos_db" "$DOCS_APROPOS_DB"
    state_set "$STATE_PACKAGES_FILE" "docs.status" "complete"
    return 0
}

module_configure() {
    printf '%s\n' ""
    printf '%s\n' "Install mandoc?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s' "Choose an option: "
    read_choice DOCS_INSTALL_MANDOC
    case "$DOCS_INSTALL_MANDOC" in
        1|2) ;;
        *) DOCS_INSTALL_MANDOC=1 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "Install man-pages?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s' "Choose an option: "
    read_choice DOCS_INSTALL_MAN_PAGES
    case "$DOCS_INSTALL_MAN_PAGES" in
        1|2) ;;
        *) DOCS_INSTALL_MAN_PAGES=1 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "Build apropos/search database?"
    printf '%s\n' "1. Yes"
    printf '%s\n' "2. Skip and continue"
    printf '%s' "Choose an option: "
    read_choice DOCS_APROPOS_DB
    case "$DOCS_APROPOS_DB" in
        1|2) ;;
        *) DOCS_APROPOS_DB=2 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "Add docs helper aliases to the registry?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s' "Choose an option: "
    read_choice DOCS_ADD_ALIAS
    case "$DOCS_ADD_ALIAS" in
        1|2) ;;
        *) DOCS_ADD_ALIAS=1 ;;
    esac

    pause_for_enter
}
