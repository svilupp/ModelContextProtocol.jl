using Test
using ModelContextProtocol: Server, Request, SuccessResponse
using WeatherServer

@testset "WeatherServer Tests" begin
    @testset "Server Creation" begin
        server = create_weather_server()
        @test server isa Server
        @test haskey(server.tools, "get-forecast")
        
        # Test tool metadata
        metadata = server.metadata["get-forecast"]
        @test metadata["name"] == "get-forecast"
        @test haskey(metadata, "description")
        @test haskey(metadata["inputSchema"], "properties")
        @test haskey(metadata["inputSchema"]["properties"], "latitude")
        @test haskey(metadata["inputSchema"]["properties"], "longitude")
    end

    @testset "Forecast Tool - Valid Input" begin
        server = create_weather_server()
        # Test with New York City coordinates
        result = WeatherServer.forecast_tool(Dict{String,Any}(
            "latitude" => 40.7128,
            "longitude" => -74.0060
        ))
        
        @test result isa Dict{String,Any}
        @test haskey(result, "content")
        @test haskey(result, "isError")
        @test !result["isError"]
        @test length(result["content"]) > 0
        @test result["content"][1]["type"] == "text"
        @test !isempty(result["content"][1]["text"])
    end

    @testset "Forecast Tool - Invalid Input" begin
        server = create_weather_server()
        
        # Test invalid latitude
        result = WeatherServer.forecast_tool(Dict{String,Any}(
            "latitude" => 91.0,  # Invalid: > 90
            "longitude" => 0.0
        ))
        @test result["isError"]
        @test contains(result["content"][1]["text"], "Invalid coordinates")

        # Test invalid longitude
        result = WeatherServer.forecast_tool(Dict{String,Any}(
            "latitude" => 0.0,
            "longitude" => 181.0  # Invalid: > 180
        ))
        @test result["isError"]
        @test contains(result["content"][1]["text"], "Invalid coordinates")

        # Test missing coordinates
        result = WeatherServer.forecast_tool(Dict{String,Any}())
        @test result["isError"]
        @test contains(result["content"][1]["text"], "Invalid coordinates")
    end

    @testset "JSON-RPC Integration" begin
        server = create_weather_server()
        
        # Test initialize request
        init_request = ModelContextProtocol.Request(
            "2.0",
            "initialize",
            Dict{String,Any}(),
            1
        )
        response = ModelContextProtocol.handle_request(server, init_request)
        @test response isa ModelContextProtocol.SuccessResponse
        @test haskey(response.result, "capabilities")
        
        # Test tool call via JSON-RPC
        forecast_request = ModelContextProtocol.Request(
            "2.0",
            "get-forecast",
            Dict{String,Any}("latitude" => 40.7128, "longitude" => -74.0060),
            2
        )
        response = ModelContextProtocol.handle_request(server, forecast_request)
        @test response isa ModelContextProtocol.SuccessResponse
        @test !response.result["isError"]
    end
end
