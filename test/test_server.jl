using Test
using ModelContextProtocol
using JSON

@testset "Server" begin
    @testset "Server Creation" begin
        server = Server("test_server", "1.0.0")
        @test server.name == "test_server"
        @test server.version == "1.0.0"
        @test !server.initialized
        @test isempty(server.tools)
        @test isempty(server.prompts)
        @test isempty(server.resources)
    end

    @testset "Registration Methods" begin
        server = Server("test_server")
        
        # Test tool registration
        handler(params) = params["x"] + params["y"]
        register_tool(server, "add", handler)
        @test haskey(server.tools, "add")
        @test server.tools["add"](Dict("x" => 1, "y" => 2)) == 3

        # Test prompt registration
        prompt = Dict("template" => "Hello, {name}!")
        register_prompt(server, "greeting", prompt)
        @test haskey(server.prompts, "greeting")
        @test server.prompts["greeting"] == prompt

        # Test resource registration
        resource = Dict("content" => "test content")
        register_resource(server, "test_resource", resource)
        @test haskey(server.resources, "test_resource")
        @test server.resources["test_resource"] == resource
    end

    @testset "Request Handling" begin
        server = Server("test_server")
        
        # Test uninitialized error
        req = Request("test", Dict{String,Any}(), 1)
        response = handle_request(server, req)
        @test response isa ErrorResponse
        @test response.error["code"] == -32002  # Server not initialized

        # Test initialization
        init_req = Request("initialize", Dict{String,Any}("id" => 1), 1)
        response = handle_request(server, init_req)
        @test response isa SuccessResponse
        @test response.result["name"] == "test_server"
        @test server.initialized == true

        # Test method not found
        req = Request("nonexistent", Dict{String,Any}(), 2)
        response = handle_request(server, req)
        @test response isa ErrorResponse
        @test response.error["code"] == -32601  # Method not found

        # Test successful tool call
        handler(params) = params["x"] + params["y"]
        register_tool(server, "add", handler)
        req = Request("add", Dict{String,Any}("x" => 1, "y" => 2), 3)
        response = handle_request(server, req)
        @test response isa SuccessResponse
        @test response.result == 3
    end

    @testset "Capabilities" begin
        server = Server("test_server")
        
        # Register some capabilities
        register_tool(server, "tool1", x -> x)
        register_prompt(server, "prompt1", "test")
        register_resource(server, "resource1", "test")

        caps = get_capabilities(server)
        @test "tool1" in caps["tools"]
        @test "prompt1" in caps["prompts"]
        @test "resource1" in caps["resources"]
    end
end
