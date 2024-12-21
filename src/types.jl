# Core types for Model Context Protocol

export Request, AbstractResponse, Response, ErrorResponse, Notification
export parse_request, parse_response, parse_error, parse_notification
export to_dict

using JSON

"""
    Request

Represents a JSON-RPC 2.0 request message.
"""
struct Request
    method::String
    params::Union{Dict{String,Any}, Nothing}
    id::Union{String,Int,Nothing}
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
    id::Union{String,Int,Nothing}
end

"""
    ErrorResponse

Represents a JSON-RPC 2.0 error response message.
"""
struct ErrorResponse <: AbstractResponse
    error::Dict{String,Any}
    id::Union{String,Int,Nothing}
end

# Add result field accessor for ErrorResponse to maintain compatibility
Base.getproperty(err::ErrorResponse, name::Symbol) = 
    name === :result ? err.error : getfield(err, name)

"""
    Notification

Represents a JSON-RPC 2.0 notification message (request without id).
"""
struct Notification
    method::String
    params::Union{Dict{String,Any}, Nothing}
end

# JSON parsing functions
function parse_request(json_str::String)::Request
    dict = JSON.parse(json_str)
    Request(
        dict["method"],
        get(dict, "params", nothing),
        get(dict, "id", nothing)
    )
end

function parse_response(json_str::String)::SuccessResponse
    dict = JSON.parse(json_str)
    SuccessResponse(
        dict["result"],
        get(dict, "id", nothing)
    )
end

function parse_error(json_str::String)::ErrorResponse
    dict = JSON.parse(json_str)
    error = dict["error"]
    ErrorResponse(
        error,
        get(dict, "id", nothing)
    )
end

function parse_notification(json_str::String)::Notification
    dict = JSON.parse(json_str)
    Notification(
        dict["method"],
        get(dict, "params", nothing)
    )
end

# Conversion to dictionary for JSON serialization
function to_dict(req::Request)
    dict = Dict{String,Any}(
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
    Dict{String,Any}(
        "jsonrpc" => "2.0",
        "result" => resp.result,
        "id" => resp.id
    )
end

function to_dict(err::ErrorResponse)
    dict = Dict{String,Any}(
        "jsonrpc" => "2.0",
        "error" => err.error
    )
    if !isnothing(err.id)
        dict["id"] = err.id
    end
    dict
end

function to_dict(notif::Notification)
    dict = Dict{String,Any}(
        "jsonrpc" => "2.0",
        "method" => notif.method
    )
    if !isnothing(notif.params)
        dict["params"] = notif.params
    end
    dict
end
