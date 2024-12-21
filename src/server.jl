# Server implementation for Model Context Protocol

export Server, register_tool, register_prompt, register_resource, run_server, handle_request

using JSON

"""
    Server

Base server type for Model Context Protocol implementation.
"""
mutable struct Server
    name::String
    version::String
    tools::Dict{String, Function}
    prompts::Dict{String, Any}
    resources::Dict{String, Any}
    initialized::Bool
end

"""
    Server(name::String, version::String="0.1.0")

Create a new MCP server with the given name and version.
"""
function Server(name::String, version::String="0.1.0")
    Server(name, version, Dict{String,Function}(), Dict{String,Any}(), Dict{String,Any}(), false)
end

# Registration methods
"""
    register_tool(server::Server, name::String, handler::Function)

Register a tool with the given name and handler function.
"""
function register_tool(server::Server, name::String, handler::Function)
    server.tools[name] = handler
    server
end

"""
    register_prompt(server::Server, name::String, prompt::Any)

Register a prompt with the given name.
"""
function register_prompt(server::Server, name::String, prompt::Any)
    server.prompts[name] = prompt
    server
end

"""
    register_resource(server::Server, name::String, resource::Any)

Register a resource with the given name.
"""
function register_resource(server::Server, name::String, resource::Any)
    server.resources[name] = resource
    server
end

# Server initialization and capabilities
function get_capabilities(server::Server)
    Dict{String,Any}(
        "tools" => collect(keys(server.tools)),
        "prompts" => collect(keys(server.prompts)),
        "resources" => collect(keys(server.resources))
    )
end

function handle_initialize(server::Server, params::Dict{String,Any})
    server.initialized = true
    SuccessResponse(
        Dict{String,Any}(
            "name" => server.name,
            "version" => server.version,
            "capabilities" => get_capabilities(server)
        ),
        get(params, "id", nothing)
    )
end

# Request handling
function handle_request(server::Server, request::Request)
    if !server.initialized && request.method != "initialize"
        return ErrorResponse(Dict("code" => -32002, "message" => "Server not initialized"), request.id)
    end

    try
        if request.method == "initialize"
            return handle_initialize(server, request.params)
        elseif haskey(server.tools, request.method)
            handler = server.tools[request.method]
            result = handler(request.params)
            return SuccessResponse(result, request.id)
        else
            return ErrorResponse(Dict("code" => -32601, "message" => "Method not found"), request.id)
        end
    catch e
        return ErrorResponse(Dict("code" => -32000, "message" => "Server error", "data" => Dict("details" => sprint(showerror, e))), request.id)
    end
end

"""
    run_server(server::Server)

Run the MCP server, processing JSON-RPC requests from stdin and writing responses to stdout.
"""
function run_server(server::Server)
    while !eof(stdin)
        line = readline(stdin)
        isempty(line) && continue

        try
            request = parse_request(line)
            response = handle_request(server, request)
            println(stdout, JSON.json(to_dict(response)))
            flush(stdout)
        catch e
            error_response = ErrorResponse(Dict("code" => -32700, "message" => "Parse error", "data" => Dict("details" => sprint(showerror, e))), nothing)
            println(stdout, JSON.json(to_dict(error_response)))
            flush(stdout)
        end
    end
end
