using Test
using ModelContextProtocol
using JSON3
using HTTP
using TimeZones
using Aqua
# Add example servers to load path
push!(LOAD_PATH, joinpath(@__DIR__, "..", "examples", "fetch", "src"))
push!(LOAD_PATH, joinpath(@__DIR__, "..", "examples", "time", "src"))
push!(LOAD_PATH, joinpath(@__DIR__, "..", "examples", "translate", "src"))

using FetchServer
using TimeServer
using TranslateServer

# Import specific functions for direct use at the global level for integration tests
import ModelContextProtocol: handle_request, Request, SuccessResponse, ErrorResponse,
                             ErrorCodes

@testset "ModelContextProtocol.jl" begin
    using ModelContextProtocol

    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(ModelContextProtocol)
    end
    @testset "Types" begin
        # Test JSON-RPC message types
        include("test_types.jl")
    end

    @testset "Server" begin
        # Test server functionality
        include("test_server.jl")
    end

    @testset "Client" begin
        # Test client functionality
        include("test_client.jl")
    end

    @testset "Example Servers" begin
        # Test example server implementations
        include("test_fetch_server.jl")
        include("test_time_server.jl")
    end

    # Integration tests with real endpoints
    @testset "Integration Tests" begin
        @testset "Fetch Server Integration" begin
            server = create_fetch_server()
            @test haskey(server.tools, "fetch")

            # Test with httpbin.org HTML endpoint
            result = server.tools["fetch"](Dict{String, Any}(
                "url" => "https://httpbin.org/html",
                "max_length" => 100
            ))
            @test haskey(result, "content")
            @test isa(result["content"], Vector)
            @test length(result["content"]) > 0

            # Test markdown conversion
            result = server.tools["fetch"](Dict{String, Any}(
                "url" => "https://httpbin.org/html",
                "raw" => false
            ))

            # Check that content is returned
            @test haskey(result, "content")
            @test isa(result["content"], Vector)
            @test length(result["content"]) > 0

            # Check that at least one content item has text
            has_text = false
            for item in result["content"]
                if item["type"] == "text" && haskey(item, "text")
                    has_text = true
                    break
                end
            end
            @test has_text
        end

        @testset "Time Server Integration" begin
            server = create_time_server()
            @test haskey(server.tools, "get_current_time")
            @test haskey(server.tools, "convert_time")

            # Test current time in UTC
            result = server.tools["get_current_time"](Dict{String, Any}(
                "timezone" => "UTC"
            ))

            # Check for content array in the result
            @test haskey(result, "content")
            @test isa(result["content"], Vector)

            # Extract JSON content
            json_content = nothing
            for item in result["content"]
                if item["type"] == "json"
                    json_content = item["json"]
                    break
                end
            end

            @test json_content !== nothing
            @test json_content["timezone"] == "UTC"
            @test !json_content["is_dst"]
            @test haskey(json_content, "time")

            # Test time conversion between timezones
            result = server.tools["convert_time"](Dict{String, Any}(
                "source_timezone" => "UTC",
                "time" => "2024-01-21T12:00:00",
                "target_timezone" => "America/New_York"
            ))

            # Extract JSON content
            json_content = nothing
            for item in result["content"]
                if item["type"] == "json"
                    json_content = item["json"]
                    break
                end
            end

            @test json_content !== nothing
            @test json_content["source"]["timezone"] == "UTC"
            @test json_content["target"]["timezone"] == "America/New_York"
            @test haskey(json_content, "time_difference")
            @test occursin("h", json_content["time_difference"])
        end

        @testset "Translate Server Integration" begin
            server = create_translate_server()
            @test haskey(server.tools, "translate_text")
            @test haskey(server.tools, "detect_language")
            @test haskey(server.tools, "get_language_info")

            # Test translation
            result = server.tools["translate_text"](Dict{String, Any}(
                "text" => "hello",
                "source_lang" => "en",
                "target_lang" => "es"
            ))

            # Extract JSON content
            json_content = nothing
            for item in result["content"]
                if item["type"] == "json"
                    json_content = item["json"]
                    break
                end
            end

            @test json_content !== nothing
            @test json_content["translated"]["text"] == "Hola"
            @test json_content["translated"]["language"]["code"] == "es"

            # Test language detection
            result = server.tools["detect_language"](Dict{String, Any}(
                "text" => "Bonjour"
            ))

            # Extract JSON content
            json_content = nothing
            for item in result["content"]
                if item["type"] == "json"
                    json_content = item["json"]
                    break
                end
            end

            @test json_content !== nothing
            @test json_content["detected_language"]["code"] == "fr"
            @test json_content["detected_language"]["name"] == "French"
        end

        @testset "Server Protocol Integration" begin
            server = create_time_server()

            # Test server initialization 
            init_req = Request("initialize", Dict{String, Any}("id" => 1), 1)
            response = handle_request(server, init_req)
            @test response isa SuccessResponse
            @test haskey(response.result, "name")
            @test haskey(response.result, "version")
            @test haskey(response.result, "capabilities")

            # Test modern tool call through tools/call
            call_req = Request("tools/call",
                Dict{String, Any}(
                    "tool" => Dict{String, Any}(
                    "name" => "get_current_time",
                    "parameters" => Dict{String, Any}(
                        "timezone" => "UTC"
                    )
                )
                ),
                2)
            response = handle_request(server, call_req)
            @test response isa SuccessResponse
            @test haskey(response.result, "content")
            @test !response.result["isError"]

            # Test error handling
            req = Request("invalid_method", Dict{String, Any}(), 3)
            response = handle_request(server, req)
            @test response isa ErrorResponse
            @test response.error["code"] == ErrorCodes.METHOD_NOT_FOUND
        end
    end
end
