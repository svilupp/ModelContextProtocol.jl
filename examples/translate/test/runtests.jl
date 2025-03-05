using Test
using ModelContextProtocol
using TranslateServer

# Import required functions for direct testing
import TranslateServer: translate_text, detect_language, get_language_info
import ModelContextProtocol: create_text_content, create_json_content, create_html_content, create_tool_response

@testset "TranslateServer" begin
    @testset "Server Creation" begin
        server = create_translate_server()
        @test server.name == "translate"
        @test server.version == "0.1.0"
        @test !server.initialized
        
        # Check tools registration
        @test haskey(server.tools, "translate_text")
        @test haskey(server.tools, "detect_language")
        @test haskey(server.tools, "get_language_info")
        
        # Check prompt registration
        @test haskey(server.prompts, "translation_help")
        
        # Check resource registration
        @test haskey(server.resources, "language_codes")
        @test haskey(server.resources, "language_families")
    end
    
    @testset "Translation Tool" begin
        # Test parameter validation
        @test_throws ArgumentError translate_text(Dict{String,Any}())
        @test_throws ArgumentError translate_text(Dict{String,Any}("text" => "hello"))
        @test_throws ArgumentError translate_text(Dict{String,Any}("target_lang" => "es"))
        @test_throws ArgumentError translate_text(Dict{String,Any}(
            "text" => "hello",
            "target_lang" => "invalid"
        ))
        
        # Test basic translation
        result = translate_text(Dict{String,Any}(
            "text" => "hello",
            "source_lang" => "en",
            "target_lang" => "es"
        ))
        
        @test haskey(result, "content")
        @test haskey(result, "isError")
        @test !result["isError"]
        
        # Check content types
        content_types = [item["type"] for item in result["content"]]
        @test "json" in content_types
        @test "text" in content_types
        @test "html" in content_types
        
        # Check translation result
        json_content = nothing
        for item in result["content"]
            if item["type"] == "json"
                json_content = item["json"]
                break
            end
        end
        
        @test json_content !== nothing
        @test json_content["original"]["text"] == "hello"
        @test json_content["original"]["language"]["code"] == "en"
        @test json_content["translated"]["text"] == "Hola"
        @test json_content["translated"]["language"]["code"] == "es"
        
        # Test automatic language detection
        result = translate_text(Dict{String,Any}(
            "text" => "Bonjour",
            "target_lang" => "en"
        ))
        
        for item in result["content"]
            if item["type"] == "json"
                json_content = item["json"]
                break
            end
        end
        
        @test json_content["original"]["language"]["code"] == "fr"
        @test json_content["translated"]["text"] == "Hello"
    end
    
    @testset "Language Detection" begin
        # Test parameter validation
        @test_throws ArgumentError detect_language(Dict{String,Any}())
        
        # Test language detection for known phrases
        result = detect_language(Dict{String,Any}("text" => "Hello"))
        
        @test haskey(result, "content")
        @test !result["isError"]
        
        for item in result["content"]
            if item["type"] == "json"
                @test item["json"]["detected_language"]["code"] == "en"
                @test item["json"]["detected_language"]["name"] == "English"
                break
            end
        end
        
        # Test detection for other languages
        test_phrases = [
            ("Gracias", "es"),
            ("Bonjour", "fr"),
            ("こんにちは", "ja"),
            ("Спасибо", "ru")
        ]
        
        for (phrase, lang_code) in test_phrases
            result = detect_language(Dict{String,Any}("text" => phrase))
            
            for item in result["content"]
                if item["type"] == "json"
                    @test item["json"]["detected_language"]["code"] == lang_code
                    break
                end
            end
        end
    end
    
    @testset "Language Info" begin
        # Test parameter validation
        @test_throws ArgumentError get_language_info(Dict{String,Any}())
        @test_throws ArgumentError get_language_info(Dict{String,Any}("lang_code" => "invalid"))
        
        # Test retrieving language info
        result = get_language_info(Dict{String,Any}("lang_code" => "en"))
        
        @test haskey(result, "content")
        @test !result["isError"]
        
        # Check content types
        content_types = [item["type"] for item in result["content"]]
        @test "json" in content_types
        @test "text" in content_types
        @test "html" in content_types
        
        # Check info result
        json_content = nothing
        for item in result["content"]
            if item["type"] == "json"
                json_content = item["json"]
                break
            end
        end
        
        @test json_content !== nothing
        @test json_content["code"] == "en"
        @test json_content["name"] == "English"
        @test json_content["family"] == "Indo-European"
        @test haskey(json_content, "script")
        @test haskey(json_content, "speakers")
        @test haskey(json_content, "hello")
    end
    
    @testset "Protocol Integration" begin
        server = create_translate_server()
        
        # Initialize server
        init_req = Request("initialize", Dict{String,Any}(), 1)
        response = handle_request(server, init_req)
        @test response isa SuccessResponse
        @test haskey(response.result, "capabilities")
        
        # Test tools/list
        list_req = Request("tools/list", Dict{String,Any}(), 2)
        response = handle_request(server, list_req)
        @test response isa SuccessResponse
        @test length(response.result["tools"]) == 3
        
        # Test tools/call for translation
        call_req = Request("tools/call", Dict{String,Any}(
            "tool" => Dict{String,Any}(
                "name" => "translate_text",
                "parameters" => Dict{String,Any}(
                    "text" => "hello",
                    "target_lang" => "es"
                )
            )
        ), 3)
        response = handle_request(server, call_req)
        @test response isa SuccessResponse
        @test haskey(response.result, "content")
        @test !response.result["isError"]
        
        # Test resources/list
        resource_req = Request("resources/list", Dict{String,Any}(), 4)
        response = handle_request(server, resource_req)
        @test response isa SuccessResponse
        @test length(response.result["resources"]) == 2
        
        # Test resources/get
        resource_req = Request("resources/get", Dict{String,Any}("name" => "language_codes"), 5)
        response = handle_request(server, resource_req)
        @test response isa SuccessResponse
        @test haskey(response.result, "content")
        @test response.result["name"] == "language_codes"
        
        # Test prompts/list
        prompt_req = Request("prompts/list", Dict{String,Any}(), 6)
        response = handle_request(server, prompt_req)
        @test response isa SuccessResponse
        @test length(response.result["prompts"]) == 1
        
        # Test prompts/get
        prompt_req = Request("prompts/get", Dict{String,Any}("name" => "translation_help"), 7)
        response = handle_request(server, prompt_req)
        @test response isa SuccessResponse
        @test haskey(response.result, "content")
        @test response.result["name"] == "translation_help"
    end
end