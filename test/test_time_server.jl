using Test
using ModelContextProtocol
using TimeZones
using Dates
using JSON3

# Add example server to load path
push!(LOAD_PATH, joinpath(@__DIR__, "..", "examples", "time", "src"))
using TimeServer

# Import specific functions for direct use
import TimeServer: get_current_time, convert_time
import ModelContextProtocol: ErrorResponse, Response

@testset "Time Server" begin
    @testset "Server Creation" begin
        server = create_time_server("test_time")
        @test server.name == "test_time"
        @test haskey(server.tools, "get_current_time")
        @test haskey(server.tools, "convert_time")
    end

    @testset "Get Current Time" begin
        server = create_time_server()

        # Test missing timezone
        @test_throws ArgumentError get_current_time(Dict{String,Any}())

        # Test invalid timezone
        @test_throws ErrorException get_current_time(Dict{String,Any}("timezone" => "Invalid/Zone"))

        # Test valid timezone
        result = get_current_time(Dict{String,Any}("timezone" => "UTC"))
        @test haskey(result, "timezone")
        @test haskey(result, "time")
        @test haskey(result, "is_dst")
        @test result["timezone"] == "UTC"
        @test !result["is_dst"]  # UTC never has DST

        # Test another timezone
        result = get_current_time(Dict{String,Any}("timezone" => "America/New_York"))
        @test result["timezone"] == "America/New_York"
    end

    @testset "Convert Time" begin
        server = create_time_server()

        # Test missing parameters
        @test_throws ArgumentError convert_time(Dict{String,Any}())
        @test_throws ArgumentError convert_time(Dict{String,Any}("source_timezone" => "UTC"))

        # Test invalid timezones
        @test_throws ErrorException convert_time(Dict{String,Any}(
            "source_timezone" => "Invalid/Zone",
            "time" => "12:00",
            "target_timezone" => "UTC"
        ))

        # Test valid conversion
        params = Dict{String,Any}(
            "source_timezone" => "America/New_York",
            "time" => "2024-01-21T16:30:00",
            "target_timezone" => "Asia/Tokyo"
        )
        result = convert_time(params)
        
        @test haskey(result, "source")
        @test haskey(result, "target")
        @test haskey(result, "time_difference")
        
        @test result["source"]["timezone"] == "America/New_York"
        @test result["target"]["timezone"] == "Asia/Tokyo"
        @test occursin("h", result["time_difference"])
        
        # Test time format validation
        @test_throws ArgumentError convert_time(Dict{String,Any}(
            "source_timezone" => "UTC",
            "time" => "25:00",  # Invalid hour
            "target_timezone" => "UTC"
        ))
    end
end
