#!/bin/bash
# MediaHub Shell Script Internationalization Library
# Provides translation support for shell scripts

# Default language
MEDIAHUB_LANG="${MEDIAHUB_LANG:-fr}"
I18N_DIR="${I18N_DIR:-$(dirname "${BASH_SOURCE[0]}")/../i18n}"

# Associative array for translations
declare -gA TRANSLATIONS

# Load translations for current language
load_translations() {
    local lang="${1:-$MEDIAHUB_LANG}"
    local lang_file="$I18N_DIR/$lang.sh"

    if [[ -f "$lang_file" ]]; then
        source "$lang_file"
        return 0
    else
        # Fallback to French
        if [[ -f "$I18N_DIR/fr.sh" ]]; then
            source "$I18N_DIR/fr.sh"
            return 0
        fi
    fi

    return 1
}

# Get translation by key
t() {
    local key="$1"
    shift
    local params=("$@")

    if [[ -n "${TRANSLATIONS[$key]}" ]]; then
        local text="${TRANSLATIONS[$key]}"

        # Replace parameters {0}, {1}, etc.
        local i=0
        for param in "${params[@]}"; do
            text="${text//\{$i\}/$param}"
            ((i++))
        done

        echo "$text"
    else
        # Return key if translation not found
        echo "$key"
    fi
}

# Select language interactively
select_language() {
    local TUI="${TUI:-whiptail}"

    if ! command -v "$TUI" &> /dev/null; then
        echo "Select language / Choisissez la langue:"
        echo "1) Français"
        echo "2) English"
        echo "3) Español"
        read -p "Choice / Choix (1-3): " choice
        case $choice in
            1) MEDIAHUB_LANG="fr" ;;
            2) MEDIAHUB_LANG="en" ;;
            3) MEDIAHUB_LANG="es" ;;
            *) MEDIAHUB_LANG="fr" ;;
        esac
    else
        MEDIAHUB_LANG=$($TUI --title "Language / Langue / Idioma" \
            --menu "Select your language:\nChoisissez votre langue:\nSeleccione su idioma:" 15 60 5 \
            "fr" "Français 🇫🇷" \
            "en" "English 🇬🇧" \
            "es" "Español 🇪🇸" \
            3>&1 1>&2 2>&3)

        if [[ -z "$MEDIAHUB_LANG" ]]; then
            MEDIAHUB_LANG="fr"
        fi
    fi

    # Save preference
    echo "MEDIAHUB_LANG=$MEDIAHUB_LANG" > "${HOME}/.mediahub_lang"

    # Load translations
    load_translations "$MEDIAHUB_LANG"

    return 0
}

# Load saved language preference
load_saved_language() {
    if [[ -f "${HOME}/.mediahub_lang" ]]; then
        source "${HOME}/.mediahub_lang"
    fi

    load_translations "$MEDIAHUB_LANG"
}

# Export functions
export -f t
export -f load_translations
export -f select_language
export -f load_saved_language
