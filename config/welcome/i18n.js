// MediaHub Internationalization System
// Provides multi-language support for the welcome wizard

class I18n {
    constructor() {
        this.currentLang = localStorage.getItem('mediahub_lang') || 'fr';
        this.translations = {};
        this.availableLanguages = [
            { code: 'fr', name: 'Français', flag: '🇫🇷' },
            { code: 'en', name: 'English', flag: '🇬🇧' },
            { code: 'es', name: 'Español', flag: '🇪🇸' },
            { code: 'de', name: 'Deutsch', flag: '🇩🇪' },
            { code: 'it', name: 'Italiano', flag: '🇮🇹' },
            { code: 'pt', name: 'Português', flag: '🇵🇹' },
            { code: 'nl', name: 'Nederlands', flag: '🇳🇱' },
            { code: 'ru', name: 'Русский', flag: '🇷🇺' },
            { code: 'zh', name: '中文', flag: '🇨🇳' },
            { code: 'ja', name: '日本語', flag: '🇯🇵' }
        ];
    }

    async loadLanguage(langCode) {
        try {
            const response = await fetch(`/i18n/${langCode}.json`);
            if (!response.ok) {
                // Fallback to French if language not found
                console.warn(`Language ${langCode} not found, falling back to French`);
                return this.loadLanguage('fr');
            }
            this.translations[langCode] = await response.json();
            return true;
        } catch (error) {
            console.error(`Failed to load language ${langCode}:`, error);
            return false;
        }
    }

    async setLanguage(langCode) {
        if (!this.translations[langCode]) {
            await this.loadLanguage(langCode);
        }

        if (this.translations[langCode]) {
            this.currentLang = langCode;
            localStorage.setItem('mediahub_lang', langCode);
            this.updatePageTranslations();
            document.documentElement.lang = langCode;
            return true;
        }
        return false;
    }

    t(key, params = {}) {
        const keys = key.split('.');
        let value = this.translations[this.currentLang];

        for (const k of keys) {
            if (value && typeof value === 'object' && k in value) {
                value = value[k];
            } else {
                console.warn(`Translation key not found: ${key}`);
                return key;
            }
        }

        // Replace parameters
        if (typeof value === 'string') {
            for (const [param, val] of Object.entries(params)) {
                value = value.replace(new RegExp(`\\{${param}\\}`, 'g'), val);
            }
        }

        return value;
    }

    updatePageTranslations() {
        // Update all elements with data-i18n attribute
        document.querySelectorAll('[data-i18n]').forEach(element => {
            const key = element.getAttribute('data-i18n');
            const translation = this.t(key);

            if (element.hasAttribute('data-i18n-html')) {
                element.innerHTML = translation;
            } else {
                element.textContent = translation;
            }
        });

        // Update placeholders
        document.querySelectorAll('[data-i18n-placeholder]').forEach(element => {
            const key = element.getAttribute('data-i18n-placeholder');
            element.placeholder = this.t(key);
        });

        // Update titles
        document.querySelectorAll('[data-i18n-title]').forEach(element => {
            const key = element.getAttribute('data-i18n-title');
            element.title = this.t(key);
        });

        // Dispatch event for custom handlers
        window.dispatchEvent(new CustomEvent('languageChanged', {
            detail: { lang: this.currentLang }
        }));
    }

    getCurrentLangInfo() {
        return this.availableLanguages.find(l => l.code === this.currentLang) || this.availableLanguages[0];
    }
}

// Create global instance
const i18n = new I18n();

// Language selection modal
function createLanguageSelector() {
    const modal = document.createElement('div');
    modal.id = 'language-modal';
    modal.innerHTML = `
        <div class="lang-modal-backdrop">
            <div class="lang-modal-content">
                <h2>🌍 <span data-i18n="welcome.language_select">Choose your language</span></h2>
                <div class="lang-grid">
                    ${i18n.availableLanguages.map(lang => `
                        <button class="lang-option ${lang.code === i18n.currentLang ? 'selected' : ''}"
                                onclick="selectLanguage('${lang.code}')"
                                data-lang="${lang.code}">
                            <span class="lang-flag">${lang.flag}</span>
                            <span class="lang-name">${lang.name}</span>
                        </button>
                    `).join('')}
                </div>
                <button class="btn btn-primary" onclick="confirmLanguage()">
                    <span data-i18n="welcome.language_confirm">Continue</span>
                </button>
            </div>
        </div>
    `;
    document.body.appendChild(modal);

    // Add styles
    const style = document.createElement('style');
    style.textContent = `
        .lang-modal-backdrop {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, 0.8);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 10000;
            animation: fadeIn 0.3s ease;
        }

        .lang-modal-content {
            background: var(--card, #1e1e3f);
            border-radius: 20px;
            padding: 40px;
            max-width: 600px;
            width: 90%;
            text-align: center;
            animation: slideUp 0.3s ease;
        }

        .lang-modal-content h2 {
            color: var(--accent2, #00d4ff);
            margin-bottom: 30px;
            font-size: 1.8em;
        }

        .lang-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
            gap: 15px;
            margin-bottom: 30px;
        }

        .lang-option {
            background: rgba(255, 255, 255, 0.05);
            border: 2px solid rgba(255, 255, 255, 0.1);
            border-radius: 12px;
            padding: 15px;
            cursor: pointer;
            transition: all 0.3s ease;
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 8px;
        }

        .lang-option:hover {
            border-color: var(--accent2, #00d4ff);
            transform: translateY(-3px);
        }

        .lang-option.selected {
            border-color: var(--accent, #00ff88);
            background: rgba(0, 255, 136, 0.1);
        }

        .lang-flag {
            font-size: 2em;
        }

        .lang-name {
            font-weight: bold;
            color: white;
        }

        .lang-selector-btn {
            position: fixed;
            top: 20px;
            right: 20px;
            background: rgba(255, 255, 255, 0.1);
            border: none;
            border-radius: 10px;
            padding: 10px 15px;
            cursor: pointer;
            font-size: 1.2em;
            transition: all 0.3s ease;
            z-index: 1000;
            color: white;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .lang-selector-btn:hover {
            background: rgba(255, 255, 255, 0.2);
        }

        @keyframes slideUp {
            from {
                opacity: 0;
                transform: translateY(20px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        @keyframes fadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
        }
    `;
    document.head.appendChild(style);
}

function selectLanguage(langCode) {
    document.querySelectorAll('.lang-option').forEach(btn => {
        btn.classList.remove('selected');
    });
    document.querySelector(`[data-lang="${langCode}"]`).classList.add('selected');
    i18n.setLanguage(langCode);
}

async function confirmLanguage() {
    const modal = document.getElementById('language-modal');
    if (modal) {
        modal.remove();
    }

    // Store that user has selected a language
    localStorage.setItem('mediahub_lang_selected', 'true');

    // Dispatch event for page initialization
    window.dispatchEvent(new CustomEvent('languageConfirmed', {
        detail: { lang: i18n.currentLang }
    }));
}

function showLanguageSelector() {
    if (!document.getElementById('language-modal')) {
        createLanguageSelector();
    } else {
        document.getElementById('language-modal').style.display = 'flex';
    }
}

function addLanguageButton() {
    const btn = document.createElement('button');
    btn.className = 'lang-selector-btn';
    btn.onclick = showLanguageSelector;

    const updateButtonText = () => {
        const langInfo = i18n.getCurrentLangInfo();
        btn.innerHTML = `${langInfo.flag} ${langInfo.name}`;
    };

    updateButtonText();
    window.addEventListener('languageChanged', updateButtonText);

    document.body.appendChild(btn);
}

// Initialize on page load
async function initI18n(showSelectorOnFirstVisit = true) {
    // Load current language
    await i18n.loadLanguage(i18n.currentLang);

    // Check if this is first visit
    const hasSelectedLanguage = localStorage.getItem('mediahub_lang_selected');

    if (showSelectorOnFirstVisit && !hasSelectedLanguage) {
        createLanguageSelector();
    } else {
        i18n.updatePageTranslations();
    }

    // Add language button to corner
    addLanguageButton();
}

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { I18n, i18n, initI18n };
}
