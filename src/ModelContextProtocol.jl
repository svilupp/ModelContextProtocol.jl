module ModelContextProtocol

using JSON
using HTTP
using TimeZones
import TimeZones: TimeZone, ZonedDateTime, UTC, astimezone
export TimeZone, ZonedDateTime, UTC, astimezone
using Dates

# Export types
export Request, AbstractResponse, SuccessResponse, ErrorResponse
export Server, Client

# Export server functions
export create_server, handle_request, register_tool
export get_capabilities, list_tools, call_tool

# Export example servers and their functions
export create_fetch_server, fetch_url
export create_time_server, get_current_time, convert_time

# Core types and functionality
include("types.jl")
include("server.jl")
include("client.jl")

# Example servers
include("servers/fetch.jl")
include("servers/time.jl")

end # module
