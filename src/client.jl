# Client implementation for Model Context Protocol

export Client, send_request, initialize_client

using JSON

"""
    Client

Base client type for Model Context Protocol implementation.
Provides methods for sending requests to MCP servers.

# Fields
- `name::String`: Name of the client
- `initialized::Bool`: Whether the client has been initialized with the server
"""
mutable struct Client
    name::String
    initialized::Bool
end

"""
    Client(name::String)

Create a new MCP client with the given name.
"""
function Client(name::String)
    Client(name, false)
end

"""
    initialize_client(client::Client)

Initialize the client by sending an initialize request to the server.
Returns the server's capabilities.

# Returns
- `Dict{String,Any}`: Server capabilities including available tools, prompts, and resources
"""
function initialize_client(client::Client)
    response = send_request(client, "initialize", Dict{String,Any}())
    client.initialized = true
    response
end

"""
    send_request(client::Client, method::String, params::Dict{String,Any})

Send a request to the server with the given method and parameters.
Returns the server's response.

# Arguments
- `client::Client`: The client sending the request
- `method::String`: The method to call on the server
- `params::Dict{String,Any}`: Parameters for the method call

# Returns
- `Dict{String,Any}`: The server's response

# Throws
- `ErrorException`: If the client is not initialized or the server returns an error
"""
function send_request(client::Client, method::String, params::Dict{String,Any})
    if !client.initialized && method != "initialize"
        throw(ErrorException("Client not initialized"))
    end
    
    request = Request(method, params, "1")
    println(stdout, JSON.json(to_dict(request)))
    flush(stdout)
    
    response = readline(stdin)
    isempty(response) && return nothing
    
    parsed = JSON.parse(response)
    if haskey(parsed, "error")
        throw(ErrorException(parsed["error"]["message"]))
    end
    parsed["result"]
end
