module TranslateServer

using HTTP
using JSON3
using ModelContextProtocol
using Dates

import ModelContextProtocol: Server, register_tool!, register_prompt!, register_resource!
import ModelContextProtocol: create_text_content, create_json_content, create_html_content,
                             create_tool_response

export create_translate_server, translate_text, detect_language, get_language_info

# Language data for demonstration
const LANGUAGES = Dict{String, Dict{String, Any}}(
    "en" => Dict{String, Any}(
        "name" => "English",
        "family" => "Indo-European",
        "script" => "Latin",
        "speakers" => "1.35 billion",
        "hello" => "Hello"
    ),
    "es" => Dict{String, Any}(
        "name" => "Spanish",
        "family" => "Indo-European",
        "script" => "Latin",
        "speakers" => "543 million",
        "hello" => "Hola"
    ),
    "fr" => Dict{String, Any}(
        "name" => "French",
        "family" => "Indo-European",
        "script" => "Latin",
        "speakers" => "267 million",
        "hello" => "Bonjour"
    ),
    "de" => Dict{String, Any}(
        "name" => "German",
        "family" => "Indo-European",
        "script" => "Latin",
        "speakers" => "132 million",
        "hello" => "Hallo"
    ),
    "zh" => Dict{String, Any}(
        "name" => "Chinese (Mandarin)",
        "family" => "Sino-Tibetan",
        "script" => "Simplified/Traditional Chinese",
        "speakers" => "1.12 billion",
        "hello" => "你好"
    ),
    "ja" => Dict{String, Any}(
        "name" => "Japanese",
        "family" => "Japonic",
        "script" => "Kanji, Hiragana, Katakana",
        "speakers" => "126 million",
        "hello" => "こんにちは"
    ),
    "ru" => Dict{String, Any}(
        "name" => "Russian",
        "family" => "Indo-European",
        "script" => "Cyrillic",
        "speakers" => "258 million",
        "hello" => "Здравствуйте"
    ),
    "ar" => Dict{String, Any}(
        "name" => "Arabic",
        "family" => "Afro-Asiatic",
        "script" => "Arabic",
        "speakers" => "274 million",
        "hello" => "مرحبا"
    )
)

# Simple demo translations (in a real app, would use a translation API)
const DEMO_TRANSLATIONS = Dict{String, Dict{String, String}}(
    "hello" => Dict{String, String}(
        "en" => "Hello",
        "es" => "Hola",
        "fr" => "Bonjour",
        "de" => "Hallo",
        "zh" => "你好",
        "ja" => "こんにちは",
        "ru" => "Здравствуйте",
        "ar" => "مرحبا"
    ),
    "goodbye" => Dict{String, String}(
        "en" => "Goodbye",
        "es" => "Adiós",
        "fr" => "Au revoir",
        "de" => "Auf Wiedersehen",
        "zh" => "再见",
        "ja" => "さようなら",
        "ru" => "До свидания",
        "ar" => "وداعا"
    ),
    "thank you" => Dict{String, String}(
        "en" => "Thank you",
        "es" => "Gracias",
        "fr" => "Merci",
        "de" => "Danke",
        "zh" => "谢谢",
        "ja" => "ありがとう",
        "ru" => "Спасибо",
        "ar" => "شكرا لك"
    ),
    "welcome" => Dict{String, String}(
        "en" => "Welcome",
        "es" => "Bienvenido",
        "fr" => "Bienvenue",
        "de" => "Willkommen",
        "zh" => "欢迎",
        "ja" => "ようこそ",
        "ru" => "Добро пожаловать",
        "ar" => "أهلا بك"
    ),
    "yes" => Dict{String, String}(
        "en" => "Yes",
        "es" => "Sí",
        "fr" => "Oui",
        "de" => "Ja",
        "zh" => "是的",
        "ja" => "はい",
        "ru" => "Да",
        "ar" => "نعم"
    ),
    "no" => Dict{String, String}(
        "en" => "No",
        "es" => "No",
        "fr" => "Non",
        "de" => "Nein",
        "zh" => "不",
        "ja" => "いいえ",
        "ru" => "Нет",
        "ar" => "لا"
    )
)

"""
    create_translate_server(name::String="translate", version::String="0.1.0")

Create a new server instance with translation capabilities.
Demonstrates the core MCP features including tools, prompts, and resources.
"""
function create_translate_server(name::String = "translate", version::String = "0.1.0")
    server = Server(name, version)

    # Register translation tool
    register_tool!(server,
        "translate_text",
        Dict{String, Any}(
            "name" => "translate_text",
            "description" => "Translate text from one language to another",
            "parameters" => Dict{String, Any}(
                "type" => "object",
                "properties" => Dict{String, Any}(
                    "text" => Dict{String, Any}(
                        "type" => "string",
                        "description" => "Text to translate"
                    ),
                    "source_lang" => Dict{String, Any}(
                        "type" => "string",
                        "description" => "Source language code (e.g., 'en', 'es', 'fr')"
                    ),
                    "target_lang" => Dict{String, Any}(
                        "type" => "string",
                        "description" => "Target language code (e.g., 'en', 'es', 'fr')"
                    )
                ),
                "required" => ["text", "target_lang"]
            )
        ))

    # Register language detection tool
    register_tool!(server,
        "detect_language",
        Dict{String, Any}(
            "name" => "detect_language",
            "description" => "Detect the language of a text",
            "parameters" => Dict{String, Any}(
                "type" => "object",
                "properties" => Dict{String, Any}(
                    "text" => Dict{String, Any}(
                    "type" => "string",
                    "description" => "Text to analyze"
                )
                ),
                "required" => ["text"]
            )
        ))

    # Register language info tool
    register_tool!(server,
        "get_language_info",
        Dict{String, Any}(
            "name" => "get_language_info",
            "description" => "Get information about a language",
            "parameters" => Dict{String, Any}(
                "type" => "object",
                "properties" => Dict{String, Any}(
                    "lang_code" => Dict{String, Any}(
                    "type" => "string",
                    "description" => "Language code (e.g., 'en', 'es', 'fr')"
                )
                ),
                "required" => ["lang_code"]
            )
        ))

    # Register a sample prompt for translation
    register_prompt!(server,
        "translation_help",
        Dict{String, Any}(
            "type" => "text",
            "text" => """
            # Translation Help

            This service provides translation capabilities between the following languages:

            - English (en)
            - Spanish (es)
            - French (fr)
            - German (de)
            - Chinese (zh)
            - Japanese (ja)
            - Russian (ru)
            - Arabic (ar)

            When translating text, you can specify both the source and target language codes.
            If the source language is not specified, the service will attempt to detect it automatically.
            """
        ))

    # Register a resource with language codes
    register_resource!(server,
        "language_codes",
        Dict{String, Any}(
            "type" => "json",
            "json" => Dict{String, Any}(
                "languages" => [
                Dict("code" => "en", "name" => "English"),
                Dict("code" => "es", "name" => "Spanish"),
                Dict("code" => "fr", "name" => "French"),
                Dict("code" => "de", "name" => "German"),
                Dict("code" => "zh", "name" => "Chinese"),
                Dict("code" => "ja", "name" => "Japanese"),
                Dict("code" => "ru", "name" => "Russian"),
                Dict("code" => "ar", "name" => "Arabic")
            ]
            )
        ))

    # Register HTML resource with rich language info
    register_resource!(server,
        "language_families",
        Dict{String, Any}(
            "type" => "html",
            "html" => """
            <h2>Language Families</h2>
            <ul>
                <li><strong>Indo-European</strong>: English, Spanish, French, German, Russian</li>
                <li><strong>Sino-Tibetan</strong>: Chinese (Mandarin)</li>
                <li><strong>Japonic</strong>: Japanese</li>
                <li><strong>Afro-Asiatic</strong>: Arabic</li>
            </ul>
            <p>Languages within the same family often share common roots and features.</p>
            """
        ))

    # Assign tool implementations
    server.tools["translate_text"] = translate_text
    server.tools["detect_language"] = detect_language
    server.tools["get_language_info"] = get_language_info

    server
end

"""
    translate_text(params::Dict)

Translate text from one language to another.
This demo version only supports a few phrases and languages.
"""
function translate_text(params::Dict)
    # Validate required parameters
    if !haskey(params, "text")
        throw(ArgumentError("Missing required parameter: text"))
    end
    if !haskey(params, "target_lang")
        throw(ArgumentError("Missing required parameter: target_lang"))
    end

    text = lowercase(strip(params["text"]))
    target_lang = params["target_lang"]
    source_lang = get(params, "source_lang", detect_language_code(text))

    # Check if the language codes are valid
    if !haskey(LANGUAGES, target_lang)
        throw(ArgumentError("Invalid target language code: $target_lang"))
    end
    if !haskey(LANGUAGES, source_lang)
        throw(ArgumentError("Invalid source language code: $source_lang"))
    end

    # Simple demo translation logic
    translated_text = if haskey(DEMO_TRANSLATIONS, text) &&
                         haskey(DEMO_TRANSLATIONS[text], target_lang)
        DEMO_TRANSLATIONS[text][target_lang]
    else
        # Fall back to a mock translation (in real app, would use a translation API)
        "[$text (translated from $(LANGUAGES[source_lang]["name"]) to $(LANGUAGES[target_lang]["name"]))]"
    end

    # Create result with multiple content types
    content = [
        create_json_content(Dict{String, Any}(
            "original" => Dict{String, Any}(
                "text" => text,
                "language" => Dict{String, Any}(
                    "code" => source_lang,
                    "name" => LANGUAGES[source_lang]["name"]
                )
            ),
            "translated" => Dict{String, Any}(
                "text" => translated_text,
                "language" => Dict{String, Any}(
                    "code" => target_lang,
                    "name" => LANGUAGES[target_lang]["name"]
                )
            ),
            "timestamp" => now() |> string
        )),
        create_text_content("""
        Translated text:
        - Original ($(LANGUAGES[source_lang]["name"])): $text
        - Translated ($(LANGUAGES[target_lang]["name"])): $translated_text
        """),
        create_html_content("""
        <div class="translation">
            <div class="original">
                <span class="language">$(LANGUAGES[source_lang]["name"]):</span>
                <span class="text">$text</span>
            </div>
            <div class="translated">
                <span class="language">$(LANGUAGES[target_lang]["name"]):</span>
                <span class="text">$translated_text</span>
            </div>
        </div>
        """)
    ]

    create_tool_response(content)
end

"""
    detect_language(params::Dict)

Detect the language of the provided text.
This demo version uses a simple heuristic based on known phrases.
"""
function detect_language(params::Dict)
    # Validate required parameters
    if !haskey(params, "text")
        throw(ArgumentError("Missing required parameter: text"))
    end

    text = lowercase(strip(params["text"]))
    detected_code = detect_language_code(text)
    confidence = 0.8  # Mock confidence score

    # Create result with JSON and text content
    content = [
        create_json_content(Dict{String, Any}(
            "text" => text,
            "detected_language" => Dict{String, Any}(
                "code" => detected_code,
                "name" => LANGUAGES[detected_code]["name"],
                "confidence" => confidence
            )
        )),
        create_text_content("""
        Language Detection Results:
        - Text: $text
        - Detected Language: $(LANGUAGES[detected_code]["name"]) ($detected_code)
        - Confidence: $(confidence * 100)%
        """)
    ]

    create_tool_response(content)
end

"""
    get_language_info(params::Dict)

Get detailed information about a specific language.
"""
function get_language_info(params::Dict)
    # Validate required parameters
    if !haskey(params, "lang_code")
        throw(ArgumentError("Missing required parameter: lang_code"))
    end

    lang_code = params["lang_code"]

    # Check if the language code is valid
    if !haskey(LANGUAGES, lang_code)
        throw(ArgumentError("Invalid language code: $lang_code"))
    end

    language = LANGUAGES[lang_code]

    # Create an HTML representation for rich display
    html_content = """
    <div class="language-info">
        <h2>$(language["name"]) ($(lang_code))</h2>
        <ul>
            <li><strong>Language Family:</strong> $(language["family"])</li>
            <li><strong>Writing System:</strong> $(language["script"])</li>
            <li><strong>Number of Speakers:</strong> $(language["speakers"])</li>
            <li><strong>Hello:</strong> $(language["hello"])</li>
        </ul>
    </div>
    """

    # Create result with multiple content types
    content = [
        create_json_content(Dict{String, Any}(
            "code" => lang_code,
            "name" => language["name"],
            "family" => language["family"],
            "script" => language["script"],
            "speakers" => language["speakers"],
            "hello" => language["hello"]
        )),
        create_text_content("""
        Language Information: $(language["name"]) ($(lang_code))
        - Language Family: $(language["family"])
        - Writing System: $(language["script"])
        - Number of Speakers: $(language["speakers"])
        - Hello: $(language["hello"])
        """),
        create_html_content(html_content)
    ]

    create_tool_response(content)
end

# Helper function to detect language based on text content
function detect_language_code(text::String)::String
    text = lowercase(strip(text))

    # Check if it's one of our demo phrases
    for (phrase, translations) in DEMO_TRANSLATIONS
        for (lang, translated) in translations
            if text == lowercase(translated)
                return lang
            end
        end
    end

    # Default to English for this demo
    return "en"
end

end # module