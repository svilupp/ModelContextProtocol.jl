using Test
using ModelContextProtocol
using TimeZones
using Dates
using TimeServer

@testset "Time Server" begin
    @testset "Server Creation" begin
        server = create_time_server()
        @test server isa ModelContextProtocol.Server
        @test length(server.tools) == 2  # Should have current_time and convert_time tools
    end

    @testset "Time Tool Registration" begin
        server = create_time_server()
        @test haskey(server.tools, "get_current_time")
        @test haskey(server.tools, "convert_time")
        @test haskey(server.metadata, "get_current_time")
        tool_spec = server.metadata["get_current_time"]
        @test tool_spec["name"] == "get_current_time"
        @test haskey(tool_spec["parameters"], "timezone")
    end

    @testset "Time Conversion" begin
        server = create_time_server()

        # Test UTC time
        result = ModelContextProtocol.call_tool(server, "get_current_time", Dict{String,Any}("timezone" => "UTC"))
        @test result isa Dict{String,Any}
        @test haskey(result, "time")
        @test haskey(result, "timezone")
        @test result["timezone"] == "UTC"

        # Test conversion to another timezone
        result = ModelContextProtocol.call_tool(server, "get_current_time", Dict{String,Any}("timezone" => "America/New_York"))
        @test result isa Dict{String,Any}
        @test haskey(result, "time")
        @test haskey(result, "timezone")
        @test result["timezone"] == "America/New_York"

        # Parse the returned time and verify it's valid
        time_str = result["time"]
        @test !isnothing(DateTime(time_str, dateformat"yyyy-mm-dd HH:MM:SS"))
    end
end
