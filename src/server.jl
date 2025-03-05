# Server implementation for Model Context Protocol
"""
    Server

Base server type for Model Context Protocol implementation.
"""
mutable struct Server
    name::AbstractString
    version::AbstractString
    tools::AbstractDict
    prompts::AbstractDict
    resources::AbstractDict
    metadata::AbstractDict
    initialized::Bool
end

"""
    Server(name::String, version::String="0.1.0")

Create a new MCP server with the given name and version.
"""
function Server(name::AbstractString, version::AbstractString = "0.1.0")
    Server(name, version, Dict{String, Function}(), Dict{String, Any}(),
        Dict{String, Any}(), Dict{String, Dict{String, Any}}(), false)
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
function register_tool!(
        server::Server, name::AbstractString, handler::Function,
        metadata::AbstractDict)
    server.tools[name] = handler
    server.metadata[name] = metadata
    server
end

function register_tool!(
        server::Server, name::AbstractString,
        handler::Union{Function, AbstractDict})
    if handler isa AbstractDict
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
            server.metadata[name] = Dict{String, Any}(
                "name" => name,
                "description" => "No description provided",
                "parameters" => Dict{String, Any}()
            )
        end
    end
    server
end

"""
    register_prompt!(server::Server, name::String, prompt::Any)

Register a prompt with the given name and content.
"""
function register_prompt!(server::Server, name::AbstractString, prompt::Any)
    server.prompts[name] = prompt
    server
end

"""
    register_resource!(server::Server, name::String, resource::Any)

Register a resource with the given name and content.
"""
function register_resource!(server::Server, name::AbstractString, resource::Any)
    server.resources[name] = resource
    server
end

# Server initialization and capabilities
"""
    get_capabilities(server::Server)

Get the server's capabilities including tools, prompts, and resources.
"""
function get_capabilities(server::Server)
    Dict{String, Any}(
        "tools" => create_tool_list(server),
        "prompts" => [Dict("name" => name) for name in keys(server.prompts)],
        "resources" => [Dict("name" => name) for name in keys(server.resources)]
    )
end

"""
    handle_initialize(server::Server, params::Dict{String, Any})

Handle the initialize request and return server information.
"""
function handle_initialize(server::Server, params::Dict{String, Any})
    server.initialized = true
    SuccessResponse(
        Dict{String, Any}(
            "name" => server.name,
            "version" => server.version,
            "capabilities" => get_capabilities(server)
        ),
        params["id"]
    )
end

# Request handling
"""
    call_tool(server::Server, tool_name::String, params::Dict{String,Any})

Call a registered tool on the server with the given parameters.
Returns the result of the tool call.
"""
function call_tool(server::Server, tool_name::AbstractString,
        params::AbstractDict)
    if !haskey(server.tools, tool_name)
        throw(ErrorException("Tool not found: $tool_name"))
    end

    handler = server.tools[tool_name]
    handler(params)
end

"""
    get_resource(server::Server, resource_name::String)

Get a registered resource by name.
"""
function get_resource(server::Server, resource_name::AbstractString)
    if !haskey(server.resources, resource_name)
        throw(ErrorException("Resource not found: $resource_name"))
    end

    server.resources[resource_name]
end

"""
    get_prompt(server::Server, prompt_name::String)

Get a registered prompt by name.
"""
function get_prompt(server::Server, prompt_name::AbstractString)
    if !haskey(server.prompts, prompt_name)
        throw(ErrorException("Prompt not found: $prompt_name"))
    end

    server.prompts[prompt_name]
end

"""
    create_tool_list(server::Server)::Vector{Dict{String,Any}}

Create a list of tool metadata including name, description, and input schema.
"""
function create_tool_list(server::Server)::Vector{Dict{String, Any}}
    [server.metadata[name] for name in keys(server.tools)]
end

"""
    handle_tools_call(server::Server, params::Dict{String,Any}, id::Union{String, Int, Nothing})

Handle a tools/call request according to the MCP specification.
"""
function handle_tools_call(server::Server, params::AbstractDict,
        id::Union{<:AbstractString, <:Integer, Nothing})
    # Validate params
    if !haskey(params, "tool") || !haskey(params["tool"], "name")
        return create_invalid_params_error(id, "Missing required field: tool.name")
    end

    tool_name = params["tool"]["name"]
    tool_params = get(params["tool"], "parameters", Dict{String, Any}())

    if !haskey(server.tools, tool_name)
        return create_method_not_found_error(id, "Tool not found: $tool_name")
    end

    try
        result = call_tool(server, tool_name, tool_params)
        return SuccessResponse(result, id)
    catch e
        return create_tool_execution_error(id, sprint(showerror, e))
    end
end

"""
    handle_resources_get(server::Server, params::Dict{String,Any}, id::Union{String, Int, Nothing})

Handle a resources/get request according to the MCP specification.
"""
function handle_resources_get(
        server::Server, params::AbstractDict,
        id::Union{<:AbstractString, <:Integer, Nothing})
    # Validate params
    if !haskey(params, "name")
        return create_invalid_params_error(id, "Missing required field: name")
    end

    resource_name = params["name"]

    try
        resource = get_resource(server, resource_name)

        # Format response according to resource type
        result = Dict{String, Any}(
            "name" => resource_name,
            "content" => resource
        )

        return SuccessResponse(result, id)
    catch e
        return create_error_response(
            ErrorCodes.UNKNOWN_RESOURCE_TYPE,
            "Resource not found or invalid",
            id,
            Dict{String, Any}("details" => sprint(showerror, e))
        )
    end
end

"""
    handle_prompts_get(server::Server, params::Dict{String,Any}, id::Union{String, Int, Nothing})

Handle a prompts/get request according to the MCP specification.
"""
function handle_prompts_get(server::Server, params::AbstractDict,
        id::Union{<:AbstractString, <:Integer, Nothing})
    # Validate params
    if !haskey(params, "name")
        return create_invalid_params_error(id, "Missing required field: name")
    end

    prompt_name = params["name"]

    try
        prompt = get_prompt(server, prompt_name)

        # Format response 
        result = Dict{String, Any}(
            "name" => prompt_name,
            "content" => prompt
        )

        return SuccessResponse(result, id)
    catch e
        return create_error_response(
            ErrorCodes.UNKNOWN_RESOURCE_TYPE,
            "Prompt not found or invalid",
            id,
            Dict{String, Any}("details" => sprint(showerror, e))
        )
    end
end

"""
    handle_request(server::Server, request::Request)

Handle an MCP request and return an appropriate response.
"""
function handle_request(server::Server, request::Request)
    # Check if server is initialized
    if !server.initialized && request.method != "initialize"
        return create_server_not_initialized_error(request.id)
    end

    # Extract request parameters safely
    params = isnothing(request.params) ? Dict{String, Any}() : request.params

    try
        if request.method == "initialize"
            return handle_initialize(server, params)

        elseif request.method == "tools/list"
            return SuccessResponse(
                Dict{String, Any}(
                    "tools" => create_tool_list(server),
                    "nextCursor" => nothing  # Pagination not implemented
                ),
                request.id)

        elseif request.method == "tools/call"
            return handle_tools_call(server, params, request.id)

        elseif request.method == "resources/list"
            resources = []
            for name in keys(server.resources)
                push!(resources, Dict{String, Any}("name" => name))
            end

            return SuccessResponse(
                Dict{String, Any}(
                    "resources" => resources,
                    "nextCursor" => nothing  # Pagination not implemented
                ),
                request.id)

        elseif request.method == "resources/get"
            return handle_resources_get(server, params, request.id)

        elseif request.method == "prompts/list"
            prompts = []
            for name in keys(server.prompts)
                push!(prompts, Dict{String, Any}("name" => name))
            end

            return SuccessResponse(
                Dict{String, Any}(
                    "prompts" => prompts,
                    "nextCursor" => nothing  # Pagination not implemented
                ),
                request.id)

        elseif request.method == "prompts/get"
            return handle_prompts_get(server, params, request.id)

            # Direct tool calling (deprecated but supported for backward compatibility)
        elseif haskey(server.tools, request.method)
            result = call_tool(server, request.method, params)
            return SuccessResponse(result, request.id)

        else
            return create_method_not_found_error(
                request.id, "Method not supported: $(request.method)")
        end
    catch e
        return create_internal_error(request.id, sprint(showerror, e))
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
            error_response = create_parse_error(nothing, sprint(showerror, e))
            println(stdout, JSON3.write(to_dict(error_response)))
            flush(stdout)
        end
    end
end
