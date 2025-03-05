# Core types for Model Context Protocol
"""
    Request

Represents a JSON-RPC 2.0 request message.
"""
struct Request
    method::AbstractString
    params::Union{AbstractDict, Nothing}
    id::Union{<:AbstractString, <:Integer, Nothing}
end

"""
    AbstractResponse

Abstract type for all JSON-RPC 2.0 response messages.
"""
abstract type AbstractResponse end

"""
    SuccessResponse

Represents a successful JSON-RPC 2.0 response message.
"""
struct SuccessResponse <: AbstractResponse
    result::Any
    id::Union{<:AbstractString, <:Integer, Nothing}
end

"""
    ErrorResponse

Represents a JSON-RPC 2.0 error response message.
"""
struct ErrorResponse <: AbstractResponse
    error::AbstractDict
    id::Union{<:AbstractString, <:Integer, Nothing}
end

# Add result field accessor for ErrorResponse to maintain compatibility
function Base.getproperty(err::ErrorResponse, name::Symbol)
    name === :result ? err.error : getfield(err, name)
end

"""
    Notification

Represents a JSON-RPC 2.0 notification message (request without id).
"""
struct Notification
    method::AbstractString
    params::Union{AbstractDict, Nothing}
end

# Enum for standard error codes according to Model Context Protocol
module ErrorCodes
    const PARSE_ERROR = -32700
    const INVALID_REQUEST = -32600
    const METHOD_NOT_FOUND = -32601
    const INVALID_PARAMS = -32602
    const INTERNAL_ERROR = -32603
    const SERVER_NOT_INITIALIZED = -32002
    const UNKNOWN_RESOURCE_TYPE = -32001
    const TOOL_EXECUTION_ERROR = -32000
end

# JSON parsing functions
function parse_request(json_str::AbstractString)::Request
    json = JSON3.read(json_str)
    # Check if this is a valid JSON-RPC 2.0 request
    if !haskey(json, "jsonrpc") || json["jsonrpc"] != "2.0" || !haskey(json, "method")
        throw(ErrorException("Invalid JSON-RPC 2.0 request"))
    end
    
    # Handle params (works with both JSON3.Object or Dict)
    params = if haskey(json, "params")
        # Keep JSON3.Object as is - it behaves like a dictionary
        json.params 
    else
        nothing
    end
    Request(
        json["method"],
        params,
        get(json, "id", nothing)
    )
end

function parse_response(json_str::AbstractString)::AbstractResponse
    json = JSON3.read(json_str)
    # Check if this is a valid JSON-RPC 2.0 response
    if !haskey(json, "jsonrpc") || json["jsonrpc"] != "2.0"
        throw(ErrorException("Invalid JSON-RPC 2.0 response"))
    end
    
    if haskey(json, "error")
        # Keep JSON3.Object as is
        return ErrorResponse(
            json["error"],
            get(json, "id", nothing)
        )
    else
        return SuccessResponse(
            json["result"],
            get(json, "id", nothing)
        )
    end
end

function parse_notification(json_str::AbstractString)::Notification
    json = JSON3.read(json_str)
    # Check if this is a valid JSON-RPC 2.0 notification
    if !haskey(json, "jsonrpc") || json["jsonrpc"] != "2.0" || !haskey(json, "method") || haskey(json, "id")
        throw(ErrorException("Invalid JSON-RPC 2.0 notification"))
    end
    
    # Handle params (works with both JSON3.Object or Dict)
    params = if haskey(json, "params")
        # Keep JSON3.Object as is
        json.params
    else
        nothing
    end
    Notification(
        json["method"],
        params
    )
end

# Create standard error responses
function create_error_response(code::Integer, message::AbstractString, id::Union{<:AbstractString, <:Integer, Nothing}=nothing, data::Union{AbstractDict, Nothing}=nothing)
    error_dict = Dict{String, Any}(
        "code" => code,
        "message" => message
    )
    if !isnothing(data)
        error_dict["data"] = data
    end
    ErrorResponse(error_dict, id)
end

function create_parse_error(id::Union{<:AbstractString, <:Integer, Nothing}=nothing, details::Union{<:AbstractString, Nothing}=nothing)
    data = isnothing(details) ? nothing : Dict{String, Any}("details" => details)
    create_error_response(ErrorCodes.PARSE_ERROR, "Parse error", id, data)
end

function create_invalid_request_error(id::Union{<:AbstractString, <:Integer, Nothing}=nothing, details::Union{<:AbstractString, Nothing}=nothing)
    data = isnothing(details) ? nothing : Dict{String, Any}("details" => details)
    create_error_response(ErrorCodes.INVALID_REQUEST, "Invalid request", id, data)
end

function create_method_not_found_error(id::Union{<:AbstractString, <:Integer, Nothing}, details::Union{<:AbstractString, Nothing}=nothing)
    data = isnothing(details) ? nothing : Dict{String, Any}("details" => details)
    create_error_response(ErrorCodes.METHOD_NOT_FOUND, "Method not found", id, data)
end

function create_invalid_params_error(id::Union{<:AbstractString, <:Integer, Nothing}, details::Union{<:AbstractString, Nothing}=nothing)
    data = isnothing(details) ? nothing : Dict{String, Any}("details" => details)
    create_error_response(ErrorCodes.INVALID_PARAMS, "Invalid params", id, data)
end

function create_internal_error(id::Union{<:AbstractString, <:Integer, Nothing}, details::Union{<:AbstractString, Nothing}=nothing)
    data = isnothing(details) ? nothing : Dict{String, Any}("details" => details)
    create_error_response(ErrorCodes.INTERNAL_ERROR, "Internal error", id, data)
end

function create_server_not_initialized_error(id::Union{<:AbstractString, <:Integer, Nothing})
    create_error_response(ErrorCodes.SERVER_NOT_INITIALIZED, "Server not initialized", id)
end

function create_unknown_resource_type_error(id::Union{<:AbstractString, <:Integer, Nothing}, resource_type::AbstractString)
    data = Dict{String, Any}("resource_type" => resource_type)
    create_error_response(ErrorCodes.UNKNOWN_RESOURCE_TYPE, "Unknown resource type", id, data)
end

function create_tool_execution_error(id::Union{<:AbstractString, <:Integer, Nothing}, details::AbstractString)
    data = Dict{String, Any}("details" => details)
    create_error_response(ErrorCodes.TOOL_EXECUTION_ERROR, "Tool execution error", id, data)
end

# Conversion to dictionary for JSON serialization
function to_dict(req::Request)
    dict = Dict{String, Any}(
        "jsonrpc" => "2.0",
        "method" => req.method
    )
    if !isnothing(req.params)
        dict["params"] = req.params
    end
    if !isnothing(req.id)
        dict["id"] = req.id
    end
    dict
end

function to_dict(resp::SuccessResponse)
    Dict{String, Any}(
        "jsonrpc" => "2.0",
        "result" => resp.result,
        "id" => resp.id
    )
end

function to_dict(err::ErrorResponse)
    dict = Dict{String, Any}(
        "jsonrpc" => "2.0",
        "error" => err.error
    )
    if !isnothing(err.id)
        dict["id"] = err.id
    end
    dict
end

function to_dict(notif::Notification)
    dict = Dict{String, Any}(
        "jsonrpc" => "2.0",
        "method" => notif.method
    )
    if !isnothing(notif.params)
        dict["params"] = notif.params
    end
    dict
end

# Helper function for standard API responses
function create_tool_response(content::Vector{Dict{String, Any}}, is_error::Bool=false, status::Union{String, Nothing}=nothing)
    result = Dict{String, Any}(
        "content" => content,
        "isError" => is_error
    )
    if !isnothing(status)
        result["status"] = status
    end
    result
end

function create_text_content(text::AbstractString)
    Dict{String, Any}(
        "type" => "text",
        "text" => text
    )
end

function create_json_content(data::AbstractDict)
    Dict{String, Any}(
        "type" => "json",
        "json" => data
    )
end

function create_html_content(html::AbstractString)
    Dict{String, Any}(
        "type" => "html",
        "html" => html
    )
end

function create_image_content(url::AbstractString, alt_text::Union{<:AbstractString, Nothing}=nothing)
    content = Dict{String, Any}(
        "type" => "image",
        "url" => url
    )
    if !isnothing(alt_text)
        content["alt_text"] = alt_text
    end
    content
end
