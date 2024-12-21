using Test
using ModelContextProtocol
using JSON
using HTTP
using TimeZones

# Import specific functions for direct use
import ModelContextProtocol: handle_request, Request, SuccessResponse, ErrorResponse

@testset "ModelContextProtocol.jl" begin
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
            result = server.tools["fetch"](Dict{String,Any}(
                "url" => "https://httpbin.org/html",
                "max_length" => 100
            ))
            @test haskey(result, "content")
            @test haskey(result, "url")
            @test result["url"] == "https://httpbin.org/html"
            @test result["length"] <= 100

            # Test markdown conversion
            result = server.tools["fetch"](Dict{String,Any}(
                "url" => "https://httpbin.org/html",
                "raw" => false
            ))
            @test !contains(result["content"], "<script>")
            @test !contains(result["content"], "<style>")
        end

        @testset "Time Server Integration" begin
            server = create_time_server()
            @test haskey(server.tools, "get_current_time")
            @test haskey(server.tools, "convert_time")

            # Test current time in UTC
            result = server.tools["get_current_time"](Dict{String,Any}(
                "timezone" => "UTC"
            ))
            @test result["timezone"] == "UTC"
            @test !result["is_dst"]
            @test haskey(result, "datetime")

            # Test time conversion between timezones
            result = server.tools["convert_time"](Dict{String,Any}(
                "source_timezone" => "UTC",
                "time" => "12:00",
                "target_timezone" => "America/New_York"
            ))
            @test result["source"]["timezone"] == "UTC"
            @test result["target"]["timezone"] == "America/New_York"
            @test haskey(result, "time_difference")
            @test occursin("h", result["time_difference"])
        end

        @testset "Server Protocol Integration" begin
            server = create_time_server()
            
            # Test server initialization
            init_req = Request("initialize", Dict{String,Any}(), 1)
            response = handle_request(server, init_req)
            @test response isa SuccessResponse
            @test haskey(response.result, "name")
            @test haskey(response.result, "version")
            @test haskey(response.result, "capabilities")

            # Test tool invocation through JSON-RPC
            req = Request("get_current_time", Dict{String,Any}("timezone" => "UTC"), 2)
            response = handle_request(server, req)
            @test response isa SuccessResponse
            @test !isnothing(response.result)
            @test haskey(response.result, "timezone")
            @test haskey(response.result, "datetime")

            # Test error handling
            req = Request("invalid_method", Dict{String,Any}(), 3)
            response = handle_request(server, req)
            @test response isa ErrorResponse
            @test response.error["code"] == -32601  # Method not found
        end
    end
end
