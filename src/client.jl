# Client implementation for Model Context Protocol

using JSON3
using Base.Threads: @spawn

import ..ModelContextProtocol: Request, Response, SuccessResponse, ErrorResponse, to_dict

"""
    Client

Base client type for Model Context Protocol implementation.
Provides methods for sending requests to MCP servers.

# Fields
- `name::String`: Name of the client
- `initialized::Bool`: Whether the client has been initialized with the server
"""
"""
    Client

A client for connecting to MCP servers.
"""
mutable struct Client
    io::Union{IO, Nothing}
    initialized::Bool
    server_info::Dict{String,Any}
    
    function Client()
        new(nothing, false, Dict{String,Any}())
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
        response = send_request(client, "initialize", Dict{String,Any}())
        if response isa SuccessResponse
            client.server_info = response.result
            client.initialized = true
        else
            throw(ErrorException("Failed to initialize: $(response.error)"))
        end
    end
    client
end

"""
    list_tools(client::Client)

List all available tools from the server.
"""
function list_tools(client::Client)
    response = send_request(client, "tools/list", Dict{String,Any}())
    if response isa SuccessResponse
        response.result
    else
        throw(ErrorException("Failed to list tools: $(response.error)"))
    end
end

"""
    list_resources(client::Client)

List all available resources from the server.
"""
function list_resources(client::Client)
    response = send_request(client, "resources/list", Dict{String,Any}())
    if response isa SuccessResponse
        response.result
    else
        throw(ErrorException("Failed to list resources: $(response.error)"))
    end
end

"""
    call_tool(client::Client, tool_name::String, params::Dict{String,Any})

Call a tool on the server with the given parameters.
"""
function call_tool(client::Client, tool_name::String, params::Dict{String,Any})
    response = send_request(client, "tools/call", Dict{String,Any}(
        "name" => tool_name,
        "params" => params
    ))
    if response isa SuccessResponse
        response.result
    else
        throw(ErrorException("Tool call failed: $(response.error)"))
    end
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
function send_request(client::Client, method::String, params::Dict{String,Any})
    if isnothing(client.io)
        throw(ErrorException("Client not connected"))
    end
    
    request = Request(method, params, "1")  # Add request ID for JSON-RPC 2.0
    write(client.io, JSON3.write(to_dict(request)))
    write(client.io, '\n')
    flush(client.io)
    
    response_str = readline(client.io)
    isempty(response_str) && return nothing
    
    json_response = JSON3.read(response_str)
    if haskey(json_response, "error")
        ErrorResponse(json_response["error"], json_response["id"])
    else
        SuccessResponse(json_response["result"], json_response["id"])
    end
end
