#!/bin/bash
# MediaHub Language Selection Script
# This script prompts the user to select their preferred language

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$PROJECT_DIR/scripts"

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check for whiptail/dialog
if command -v whiptail &> /dev/null; then
    TUI="whiptail"
elif command -v dialog &> /dev/null; then
    TUI="dialog"
else
    TUI=""
fi

show_header() {
    clear
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  🌍 MediaHub - Language Selection${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
}

# Interactive language selection
select_language_interactive() {
    if [[ -n "$TUI" ]]; then
        MEDIAHUB_LANG=$($TUI --title "🌍 Language / Langue / Idioma" \
            --menu "\nSelect your language:\nChoisissez votre langue:\nSeleccione su idioma:\n" 18 60 6 \
            "fr" "🇫🇷  Français (French)" \
            "en" "🇬🇧  English" \
            "es" "🇪🇸  Español (Spanish)" \
            "de" "🇩🇪  Deutsch (German) - Coming soon" \
            "it" "🇮🇹  Italiano (Italian) - Coming soon" \
            "pt" "🇵🇹  Português (Portuguese) - Coming soon" \
            3>&1 1>&2 2>&3)

        if [[ $? -ne 0 ]] || [[ -z "$MEDIAHUB_LANG" ]]; then
            MEDIAHUB_LANG="fr"
        fi
    else
        show_header
        echo "Select your language / Choisissez votre langue / Seleccione su idioma:"
        echo ""
        echo "  1) 🇫🇷  Français (French)"
        echo "  2) 🇬🇧  English"
        echo "  3) 🇪🇸  Español (Spanish)"
        echo ""
        read -p "Your choice / Votre choix / Su elección [1-3]: " choice

        case "$choice" in
            2) MEDIAHUB_LANG="en" ;;
            3) MEDIAHUB_LANG="es" ;;
            *) MEDIAHUB_LANG="fr" ;;
        esac
    fi

    # Save language preference
    save_language_preference

    # Confirmation
    case "$MEDIAHUB_LANG" in
        en)
            echo -e "${GREEN}✓ Language set to English${NC}"
            ;;
        es)
            echo -e "${GREEN}✓ Idioma configurado a Español${NC}"
            ;;
        *)
            echo -e "${GREEN}✓ Langue définie sur Français${NC}"
            ;;
    esac
}

# Save language preference to file
save_language_preference() {
    # Save to home directory
    echo "MEDIAHUB_LANG=$MEDIAHUB_LANG" > "${HOME}/.mediahub_lang"

    # Also save to config if it exists
    if [[ -d "$PROJECT_DIR/config" ]]; then
        echo "MEDIAHUB_LANG=$MEDIAHUB_LANG" > "$PROJECT_DIR/config/.lang"
    fi

    # Export for current session
    export MEDIAHUB_LANG
}

# Load language preference
load_language_preference() {
    # Check home directory first
    if [[ -f "${HOME}/.mediahub_lang" ]]; then
        source "${HOME}/.mediahub_lang"
        return 0
    fi

    # Check config directory
    if [[ -f "$PROJECT_DIR/config/.lang" ]]; then
        source "$PROJECT_DIR/config/.lang"
        return 0
    fi

    # Default to French
    MEDIAHUB_LANG="fr"
    return 1
}

# Load translations
load_translations() {
    local lang_file="$SCRIPTS_DIR/i18n/${MEDIAHUB_LANG}.sh"

    if [[ -f "$lang_file" ]]; then
        source "$lang_file"
        return 0
    else
        # Fallback to French
        if [[ -f "$SCRIPTS_DIR/i18n/fr.sh" ]]; then
            source "$SCRIPTS_DIR/i18n/fr.sh"
            return 0
        fi
    fi

    echo -e "${YELLOW}Warning: Translation file not found for $MEDIAHUB_LANG${NC}"
    return 1
}

# Main function
main() {
    # Check if language already selected
    if load_language_preference; then
        # Language already selected, ask if want to change
        if [[ "$1" == "--force" ]] || [[ "$1" == "-f" ]]; then
            select_language_interactive
        else
            case "$MEDIAHUB_LANG" in
                en) echo "Current language: English" ;;
                es) echo "Idioma actual: Español" ;;
                *) echo "Langue actuelle: Français" ;;
            esac

            if [[ -n "$TUI" ]]; then
                if $TUI --title "Language" --yesno "Keep current language?\nGarder la langue actuelle?\n¿Mantener idioma actual?" 10 50; then
                    echo "Language preference kept."
                else
                    select_language_interactive
                fi
            fi
        fi
    else
        # First time, select language
        select_language_interactive
    fi

    # Load translations
    load_translations

    # Export for use in other scripts
    export MEDIAHUB_LANG
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
