# Client implementation for Model Context Protocol
"""
    Client

A client for connecting to MCP servers.
"""
mutable struct Client
    io::Union{IO, Nothing}
    initialized::Bool
    server_info::AbstractDict
    id_counter::Integer

    function Client()
        new(nothing, false, Dict{String, Any}(), 1)
    end
end

"""
    connect!(client::Client, io::IO)

Connect the client to a server using the provided IO stream.
"""
function connect!(client::Client, io::IO)
    client.io = io
    client
end

"""
    initialize!(client::Client)

Initialize the connection with the server.
"""
function initialize!(client::Client)
    if !client.initialized
        response = send_request(client, "initialize", Dict{String, Any}())
        if response isa SuccessResponse
            client.server_info = response.result
            client.initialized = true
        else
            throw(ErrorException("Failed to initialize: $(response.error["message"])"))
        end
    end
    client
end

"""
    list_tools(client::Client; cursor::Union{String, Nothing}=nothing)

List available tools from the server.
Optionally provide a cursor for pagination.
"""
function list_tools(client::Client; cursor::Union{<:AbstractString, Nothing}=nothing)
    params = Dict{String, Any}()
    if !isnothing(cursor)
        params["cursor"] = cursor
    end
    
    response = send_request(client, "tools/list", params)
    if response isa SuccessResponse
        response.result["tools"]
    else
        throw(ErrorException("Failed to list tools: $(response.error["message"])"))
    end
end

"""
    list_resources(client::Client; cursor::Union{String, Nothing}=nothing)

List available resources from the server.
Optionally provide a cursor for pagination.
"""
function list_resources(client::Client; cursor::Union{<:AbstractString, Nothing}=nothing)
    params = Dict{String, Any}()
    if !isnothing(cursor)
        params["cursor"] = cursor
    end
    
    response = send_request(client, "resources/list", params)
    if response isa SuccessResponse
        response.result["resources"]
    else
        throw(ErrorException("Failed to list resources: $(response.error["message"])"))
    end
end

"""
    list_prompts(client::Client; cursor::Union{String, Nothing}=nothing)

List available prompts from the server.
Optionally provide a cursor for pagination.
"""
function list_prompts(client::Client; cursor::Union{<:AbstractString, Nothing}=nothing)
    params = Dict{String, Any}()
    if !isnothing(cursor)
        params["cursor"] = cursor
    end
    
    response = send_request(client, "prompts/list", params)
    if response isa SuccessResponse
        response.result["prompts"]
    else
        throw(ErrorException("Failed to list prompts: $(response.error["message"])"))
    end
end

"""
    get_resource(client::Client, name::String)

Get a specific resource from the server by name.
"""
function get_resource(client::Client, name::AbstractString)
    params = Dict{String, Any}("name" => name)
    response = send_request(client, "resources/get", params)
    if response isa SuccessResponse
        response.result
    else
        throw(ErrorException("Failed to get resource: $(response.error["message"])"))
    end
end

"""
    get_prompt(client::Client, name::String)

Get a specific prompt from the server by name.
"""
function get_prompt(client::Client, name::AbstractString)
    params = Dict{String, Any}("name" => name)
    response = send_request(client, "prompts/get", params)
    if response isa SuccessResponse
        response.result
    else
        throw(ErrorException("Failed to get prompt: $(response.error["message"])"))
    end
end

"""
    call_tool(client::Client, tool_name::String, params::Dict{String,Any})

Call a tool on the server with the given parameters.
"""
function call_tool(client::Client, tool_name::AbstractString, parameters::AbstractDict)
    params = Dict{String, Any}(
        "tool" => Dict{String, Any}(
            "name" => tool_name,
            "parameters" => parameters
        )
    )
    
    response = send_request(client, "tools/call", params)
    if response isa SuccessResponse
        response.result
    else
        throw(ErrorException("Tool call failed: $(response.error["message"])"))
    end
end

"""
    extract_content(response::Dict{String,Any})

Extract and process content from a tool response.
"""
function extract_content(response::AbstractDict)
    if !haskey(response, "content") || !isa(response["content"], Vector)
        return nothing
    end
    
    result = []
    for item in response["content"]
        if !haskey(item, "type")
            continue
        end
        
        if item["type"] == "text" && haskey(item, "text")
            push!(result, item["text"])
        elseif item["type"] == "json" && haskey(item, "json")
            push!(result, item["json"])
        elseif item["type"] == "html" && haskey(item, "html")
            push!(result, html_to_markdown(item["html"]))
        elseif item["type"] == "image" && haskey(item, "url")
            push!(result, Dict("url" => item["url"], "alt_text" => get(item, "alt_text", "")))
        end
    end
    
    return result
end

"""
    close(client::Client)

Close the connection to the server.
"""
function close(client::Client)
    if !isnothing(client.io)
        close(client.io)
        client.io = nothing
        client.initialized = false
        empty!(client.server_info)
    end
end

# Internal helper to send requests and receive responses
function send_request(client::Client, method::AbstractString, params::AbstractDict)
    if isnothing(client.io)
        throw(ErrorException("Client not connected"))
    end
    
    # Generate a unique request ID
    request_id = string(client.id_counter)
    client.id_counter += 1

    request = Request(method, params, request_id)
    write(client.io, JSON3.write(to_dict(request)))
    write(client.io, '\n')
    flush(client.io)

    response_str = readline(client.io)
    isempty(response_str) && return nothing

    # Parse the response
    try
        return parse_response(response_str)
    catch e
        throw(ErrorException("Failed to parse response: $(sprint(showerror, e))"))
    end
end

"""
    send_notification(client::Client, method::String, params::Dict{String,Any})

Send a notification to the server (no response expected).
"""
function send_notification(client::Client, method::AbstractString, params::AbstractDict)
    if isnothing(client.io)
        throw(ErrorException("Client not connected"))
    end

    notification = Notification(method, params)
    write(client.io, JSON3.write(to_dict(notification)))
    write(client.io, '\n')
    flush(client.io)
    
    return nothing
end
