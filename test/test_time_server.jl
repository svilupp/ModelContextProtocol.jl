using TimeServer
using ModelContextProtocol

# Import specific functions for direct use
import TimeServer: get_current_time, convert_time
using ModelContextProtocol: ErrorResponse, SuccessResponse, 
                           Request, handle_request, get_prompt

@testset "Time Server" begin
    @testset "Server Creation" begin
        server = create_time_server("test_time")
        @test server.name == "test_time"
        @test haskey(server.tools, "get_current_time")
        @test haskey(server.tools, "convert_time")
        @test haskey(server.prompts, "time_zone_help") # Check the new prompt
    end

    @testset "Get Current Time" begin
        server = create_time_server()

        # Test missing timezone
        @test_throws ArgumentError get_current_time(Dict{String, Any}())

        # Test invalid timezone
        @test_throws ErrorException get_current_time(Dict{String, Any}("timezone" => "Invalid/Zone"))

        # Test valid timezone
        result = get_current_time(Dict{String, Any}("timezone" => "UTC"))
        @test haskey(result, "content")
        @test haskey(result, "isError")
        @test !result["isError"]

        # Verify content structure
        @test length(result["content"]) == 2
        @test result["content"][1]["type"] == "json"
        @test result["content"][1]["json"]["timezone"] == "UTC"
        @test !result["content"][1]["json"]["is_dst"]  # UTC never has DST
        @test result["content"][2]["type"] == "text"
        @test occursin("UTC", result["content"][2]["text"])

        # Test another timezone
        result = get_current_time(Dict{String, Any}("timezone" => "America/New_York"))
        @test result["content"][1]["json"]["timezone"] == "America/New_York"
    end

    @testset "Convert Time" begin
        server = create_time_server()

        # Test missing parameters
        @test_throws ArgumentError convert_time(Dict{String, Any}())
        @test_throws ArgumentError convert_time(Dict{String, Any}("source_timezone" => "UTC"))

        # Test invalid timezones
        @test_throws ErrorException convert_time(Dict{String, Any}(
            "source_timezone" => "Invalid/Zone",
            "time" => "12:00",
            "target_timezone" => "UTC"
        ))

        # Test valid conversion
        params = Dict{String, Any}(
            "source_timezone" => "America/New_York",
            "time" => "2024-01-21T16:30:00",
            "target_timezone" => "Asia/Tokyo"
        )
        result = convert_time(params)

        @test haskey(result, "content")
        @test haskey(result, "isError")
        @test !result["isError"]

        # Verify content structure
        @test length(result["content"]) == 2
        @test result["content"][1]["type"] == "json"
        @test result["content"][2]["type"] == "text"

        json_result = result["content"][1]["json"]
        @test json_result["source"]["timezone"] == "America/New_York"
        @test json_result["target"]["timezone"] == "Asia/Tokyo"
        @test haskey(json_result, "time_difference")
        @test occursin("h", json_result["time_difference"])

        # Verify text format
        @test occursin("Time Conversion", result["content"][2]["text"])
        @test occursin("America/New_York", result["content"][2]["text"])
        @test occursin("Asia/Tokyo", result["content"][2]["text"])

        # Test time format validation
        @test_throws ArgumentError convert_time(Dict{String, Any}(
            "source_timezone" => "UTC",
            "time" => "25:00",  # Invalid hour
            "target_timezone" => "UTC"
        ))
    end

    @testset "Protocol Integration" begin
        server = create_time_server()

        # Initialize server with the id in params
        init_req = Request("initialize", Dict{String, Any}("id" => 1), 1)
        response = handle_request(server, init_req)
        @test response isa SuccessResponse
        @test haskey(response.result, "capabilities")

        # Test tools/list
        list_req = Request("tools/list", Dict{String, Any}(), 2)
        response = handle_request(server, list_req)
        @test response isa SuccessResponse
        @test length(response.result["tools"]) == 2  # get_current_time and convert_time

        # Test tools/call for get_current_time
        call_req = Request("tools/call",
            Dict{String, Any}(
                "tool" => Dict{String, Any}(
                "name" => "get_current_time",
                "parameters" => Dict{String, Any}(
                    "timezone" => "UTC"
                )
            )
            ),
            3)
        response = handle_request(server, call_req)
        @test response isa SuccessResponse
        @test haskey(response.result, "content")
        @test !response.result["isError"]

        # Test prompts/get
        prompt_req = Request("prompts/list", Dict{String, Any}(), 4)
        response = handle_request(server, prompt_req)
        @test response isa SuccessResponse
        @test length(response.result["prompts"]) == 1
        @test response.result["prompts"][1]["name"] == "time_zone_help"

        # Test direct get_prompt
        prompt = get_prompt(server, "time_zone_help")
        @test haskey(prompt, "type")
        @test prompt["type"] == "text"
        @test haskey(prompt, "text")
        @test occursin("Time Zone Help", prompt["text"])
    end
end
