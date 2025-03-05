#!/usr/bin/env julia

using Pkg
Pkg.activate(dirname(@__DIR__))

using ModelContextProtocol
using JSON3
using TranslateServer

# Create a translation server
server = create_translate_server()

# Create a client
client = Client()

# Set up IO pipes for communication between client and server
server_in, client_out = Base.Pipe()
client_in, server_out = Base.Pipe()
Base.link_pipe!(server_in, reader_supports_async=true, writer_supports_async=true)
Base.link_pipe!(client_in, reader_supports_async=true, writer_supports_async=true)

# Set up the server to read from server_in and write to server_out
@async begin
    redirect_stdin(server_in)
    redirect_stdout(server_out)
    ModelContextProtocol.run_server(server)
end

# Connect client to the appropriate IO
connect!(client, IOBuffer(client_out.data))

# Initialize the client
println("Initializing connection to translation server...")
initialize!(client)
println("Connected to $(client.server_info["name"]) v$(client.server_info["version"])")

# List available tools
println("\nAvailable tools:")
tools = list_tools(client)
for tool in tools
    println("- $(tool["name"]): $(tool["description"])")
end

# List available prompts
println("\nAvailable prompts:")
prompts = list_prompts(client)
for prompt in prompts
    println("- $(prompt["name"])")
end

# Get help about translation
println("\nRetrieving translation help prompt...")
translation_help = get_prompt(client, "translation_help")
println(translation_help["content"]["text"])

# List available resources
println("\nAvailable resources:")
resources = list_resources(client)
for resource in resources
    println("- $(resource["name"])")
end

# Get language codes resource
println("\nRetrieving language codes resource...")
language_codes = get_resource(client, "language_codes")
println("Supported languages:")
for language in language_codes["content"]["json"]["languages"]
    println("- $(language["name"]) ($(language["code"]))")
end

# Get language families (HTML resource)
println("\nRetrieving language families resource...")
language_families = get_resource(client, "language_families")
# Convert HTML to text for display
println(ModelContextProtocol.html_to_markdown(language_families["content"]["html"]))

# Demonstrate language detection
function test_language_detection(text)
    println("\nDetecting language for: \"$text\"")
    result = call_tool(client, "detect_language", Dict{String,Any}("text" => text))
    
    # Extract the text content for display
    for content_item in result["content"]
        if content_item["type"] == "text"
            println(content_item["text"])
            break
        end
    end
end

test_language_detection("Hello")
test_language_detection("Hola")
test_language_detection("Bonjour")
test_language_detection("こんにちは")

# Demonstrate language info retrieval
function test_language_info(lang_code)
    println("\nGetting info for language: $lang_code")
    result = call_tool(client, "get_language_info", Dict{String,Any}("lang_code" => lang_code))
    
    # Extract the text content for display
    for content_item in result["content"]
        if content_item["type"] == "text"
            println(content_item["text"])
            break
        end
    end
end

test_language_info("en")
test_language_info("ja")

# Demonstrate translation
function test_translation(text, source_lang, target_lang)
    println("\nTranslating \"$text\" from $source_lang to $target_lang")
    result = call_tool(client, "translate_text", Dict{String,Any}(
        "text" => text,
        "source_lang" => source_lang,
        "target_lang" => target_lang
    ))
    
    # Extract the text content for display
    for content_item in result["content"]
        if content_item["type"] == "text"
            println(content_item["text"])
            break
        end
    end
end

test_translation("hello", "en", "es")
test_translation("thank you", "en", "fr")
test_translation("goodbye", "en", "ja")

# Demonstrate auto language detection in translation
function test_auto_translation(text, target_lang)
    println("\nAuto-detecting language and translating \"$text\" to $target_lang")
    result = call_tool(client, "translate_text", Dict{String,Any}(
        "text" => text,
        "target_lang" => target_lang
    ))
    
    # Extract the text content for display
    for content_item in result["content"]
        if content_item["type"] == "text"
            println(content_item["text"])
            break
        end
    end
end

test_auto_translation("hola", "en")
test_auto_translation("merci", "de")

println("\nTranslation demonstration complete.")