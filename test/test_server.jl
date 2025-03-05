using ModelContextProtocol
# Import internal functions that we need to test directly
using ModelContextProtocol: handle_request, get_capabilities,
                            ErrorCodes, SuccessResponse, ErrorResponse, Request

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
    register_tool!(server, "add", handler)
    @test haskey(server.tools, "add")
    @test server.tools["add"](Dict("x" => 1, "y" => 2)) == 3

    # Test prompt registration
    prompt = Dict("type" => "text", "text" => "Hello, {name}!")
    register_prompt!(server, "greeting", prompt)
    @test haskey(server.prompts, "greeting")
    @test server.prompts["greeting"] == prompt

    # Test resource registration
    resource = Dict("type" => "json", "content" => Dict("key" => "value"))
    register_resource!(server, "test_resource", resource)
    @test haskey(server.resources, "test_resource")
    @test server.resources["test_resource"] == resource
end

@testset "Request Handling - Core Methods" begin
    server = Server("test_server")

    # Test uninitialized error
    req = Request("test", Dict{String, Any}(), 1)
    response = handle_request(server, req)
    @test response isa ErrorResponse
    @test response.error["code"] == ErrorCodes.SERVER_NOT_INITIALIZED

    # Test initialization
    init_req = Request("initialize", Dict{String, Any}("id" => 1), 1)
    response = handle_request(server, init_req)
    @test response isa SuccessResponse
    @test response.result["name"] == "test_server"
    @test server.initialized == true

    # Test method not found
    req = Request("nonexistent", Dict{String, Any}(), 2)
    response = handle_request(server, req)
    @test response isa ErrorResponse
    @test response.error["code"] == ErrorCodes.METHOD_NOT_FOUND

    # Test tools/list
    req = Request("tools/list", Dict{String, Any}(), 3)
    response = handle_request(server, req)
    @test response isa SuccessResponse
    @test haskey(response.result, "tools")
    @test haskey(response.result, "nextCursor")

    # Test resources/list
    req = Request("resources/list", Dict{String, Any}(), 4)
    response = handle_request(server, req)
    @test response isa SuccessResponse
    @test haskey(response.result, "resources")
    @test haskey(response.result, "nextCursor")

    # Test prompts/list
    req = Request("prompts/list", Dict{String, Any}(), 5)
    response = handle_request(server, req)
    @test response isa SuccessResponse
    @test haskey(response.result, "prompts")
    @test haskey(response.result, "nextCursor")
end

@testset "Request Handling - Tool Calls" begin
    server = Server("test_server")

    # Initialize server
    init_req = Request("initialize", Dict{String, Any}(), 1)
    handle_request(server, init_req)

    # Register test tool
    handler(params) = create_tool_response([
        create_text_content("Result: $(params["x"] + params["y"])")
    ])
    register_tool!(server,
        "add",
        handler,
        Dict{String, Any}(
            "name" => "add",
            "description" => "Add two numbers",
            "parameters" => Dict{String, Any}(
                "type" => "object",
                "properties" => Dict{String, Any}(
                    "x" => Dict{String, Any}("type" => "number"),
                    "y" => Dict{String, Any}("type" => "number")
                ),
                "required" => ["x", "y"]
            )
        ))

    # Test modern tools/call method
    req = Request("tools/call",
        Dict{String, Any}(
            "tool" => Dict{String, Any}(
            "name" => "add",
            "parameters" => Dict{String, Any}(
                "x" => 1,
                "y" => 2
            )
        )
        ),
        2)
    response = handle_request(server, req)
    @test response isa SuccessResponse
    @test haskey(response.result, "content")
    @test response.result["isError"] == false

    # Test legacy direct tool call (backward compatibility)
    req = Request("add", Dict{String, Any}("x" => 3, "y" => 4), 3)
    response = handle_request(server, req)
    @test response isa SuccessResponse
    @test haskey(response.result, "content")
    @test response.result["isError"] == false

    # Test invalid tool call
    req = Request("tools/call", Dict{String, Any}(), 4)
    response = handle_request(server, req)
    @test response isa ErrorResponse
    @test response.error["code"] == ErrorCodes.INVALID_PARAMS

    req = Request("tools/call",
        Dict{String, Any}(
            "tool" => Dict{String, Any}(
            "name" => "nonexistent"
        )
        ), 5)
    response = handle_request(server, req)
    @test response isa ErrorResponse
    @test response.error["code"] == ErrorCodes.METHOD_NOT_FOUND
end

@testset "Resources and Prompts" begin
    server = Server("test_server")

    # Initialize server
    init_req = Request("initialize", Dict{String, Any}(), 1)
    handle_request(server, init_req)

    # Register a test prompt
    prompt_content = Dict("type" => "text", "text" => "This is a test prompt")
    register_prompt!(server, "test_prompt", prompt_content)

    # Register a test resource
    resource_content = Dict("type" => "json", "data" => Dict("key" => "value"))
    register_resource!(server, "test_resource", resource_content)

    # Test prompts/get
    req = Request("prompts/get", Dict{String, Any}("name" => "test_prompt"), 2)
    response = handle_request(server, req)
    @test response isa SuccessResponse
    @test response.result["name"] == "test_prompt"
    @test response.result["content"] == prompt_content

    # Test resources/get
    req = Request("resources/get", Dict{String, Any}("name" => "test_resource"), 3)
    response = handle_request(server, req)
    @test response isa SuccessResponse
    @test response.result["name"] == "test_resource"
    @test response.result["content"] == resource_content

    # Test nonexistent prompt
    req = Request("prompts/get", Dict{String, Any}("name" => "nonexistent"), 4)
    response = handle_request(server, req)
    @test response isa ErrorResponse

    # Test invalid resource request
    req = Request("resources/get", Dict{String, Any}(), 5)
    response = handle_request(server, req)
    @test response isa ErrorResponse
    @test response.error["code"] == ErrorCodes.INVALID_PARAMS
end

@testset "Capabilities" begin
    server = Server("test_server")

    # Register some capabilities
    register_tool!(server,
        "tool1",
        x -> x,
        Dict{String, Any}(
            "name" => "tool1",
            "description" => "Test tool",
            "parameters" => Dict{String, Any}()
        ))
    register_prompt!(server, "prompt1", "test")
    register_resource!(server, "resource1", "test")

    caps = get_capabilities(server)
    @test any(t -> t["name"] == "tool1", caps["tools"])
    @test any(p -> p["name"] == "prompt1", caps["prompts"])
    @test any(r -> r["name"] == "resource1", caps["resources"])
end
