# Server implementation for Model Context Protocol

export Server, register_tool!, register_prompt!, register_resource!, run_server, handle_request

using JSON3

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
    metadata::Dict{String, Dict{String, Any}}
    initialized::Bool
end

"""
    Server(name::String, version::String="0.1.0")

Create a new MCP server with the given name and version.
"""
function Server(name::String, version::String="0.1.0")
    Server(name, version, Dict{String,Function}(), Dict{String,Any}(), Dict{String,Any}(), Dict{String,Dict{String,Any}}(), false)
end

# Registration methods
"""
    register_tool!(server::Server, name::String, handler::Function, metadata::Dict{String,Any})
    register_tool!(server::Server, name::String, handler::Union{Function,Dict{String,Any}})

Register a tool with the given name and either:
1. A handler function and metadata dictionary
2. Just a handler function (metadata will be initialized with defaults)
3. Just a metadata dictionary (handler will be a placeholder)
"""
function register_tool!(server::Server, name::String, handler::Function, metadata::Dict{String,Any})
    server.tools[name] = handler
    server.metadata[name] = metadata
    server
end

function register_tool!(server::Server, name::String, handler::Union{Function,Dict{String,Any}})
    if handler isa Dict{String,Any}
        # Store metadata in server's metadata
        server.metadata[name] = handler
        # If there's an existing function, keep it, otherwise set a placeholder
        if !haskey(server.tools, name)
            server.tools[name] = (params) -> throw(ErrorException("Tool function not implemented"))
        end
    else
        # It's a function, store it directly
        server.tools[name] = handler
        # Initialize metadata if not present
        if !haskey(server.metadata, name)
            server.metadata[name] = Dict{String,Any}(
                "name" => name,
                "description" => "No description provided",
                "parameters" => Dict{String,Any}()
            )
        end
    end
    server
end

"""
    register_prompt!(server::Server, name::String, prompt::Any)

Register a prompt with the given name.
"""
function register_prompt!(server::Server, name::String, prompt::Any)
    server.prompts[name] = prompt
    server
end

"""
    register_resource!(server::Server, name::String, resource::Any)

Register a resource with the given name.
"""
function register_resource!(server::Server, name::String, resource::Any)
    server.resources[name] = resource
    server
end

# Server initialization and capabilities
function get_capabilities(server::Server)
    Dict{String,Any}(
        "tools" => create_tool_list(server),
        "prompts" => [Dict("name" => name) for name in keys(server.prompts)],
        "resources" => [Dict("name" => name) for name in keys(server.resources)]
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
"""
    call_tool(server::Server, tool_name::String, params::Dict{String,Any})

Call a registered tool on the server with the given parameters.
"""
function call_tool(server::Server, tool_name::String, params::Dict{String,Any})
    if !haskey(server.tools, tool_name)
        throw(ErrorException("Tool not found: $tool_name"))
    end
    
    handler = server.tools[tool_name]
    handler(params)
end

"""
    create_tool_list(server::Server)::Vector{Dict{String,Any}}

Create a list of tool metadata including name, description, and input schema.
"""
function create_tool_list(server::Server)::Vector{Dict{String,Any}}
    [server.metadata[name] for name in keys(server.tools)]
end

function handle_request(server::Server, request::Request)
    if !server.initialized && request.method != "initialize"
        return ErrorResponse(Dict("code" => -32002, "message" => "Server not initialized"), request.id)
    end

    try
        if request.method == "initialize"
            return handle_initialize(server, request.params)
        elseif request.method == "tools/list"
            return SuccessResponse(Dict(
                "tools" => create_tool_list(server),
                "nextCursor" => nothing  # Minimal implementation without pagination
            ), request.id)
        elseif request.method == "resources/list"
            return SuccessResponse(Dict(
                "resources" => [],  # Minimal implementation with empty resources
                "nextCursor" => nothing
            ), request.id)
        elseif haskey(server.tools, request.method)
            result = call_tool(server, request.method, request.params)
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
            println(stdout, JSON3.write(to_dict(response)))
            flush(stdout)
        catch e
            error_response = ErrorResponse(Dict("code" => -32700, "message" => "Parse error", "data" => Dict("details" => sprint(showerror, e))), nothing)
            println(stdout, JSON3.write(to_dict(error_response)))
            flush(stdout)
        end
    end
end
