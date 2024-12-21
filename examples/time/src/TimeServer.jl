module TimeServer

using Dates: DateTime, @dateformat_str, Millisecond, Hour, format
using TimeZones: TimeZone, ZonedDateTime, now, astimezone, hour, isdst, VariableTimeZone
using ModelContextProtocol

export create_time_server, get_current_time, convert_time

"""
    create_time_server(name::String="time", version::String="0.1.0")

Create a new server instance with time conversion capabilities.
"""
function create_time_server(name::String="time", version::String="0.1.0")
    server = Server(name, version)
    
    # Register current time tool
    register_tool!(server, "get_current_time", Dict{String,Any}(
        "name" => "get_current_time",
        "description" => "Get current time in a specific timezone",
        "parameters" => Dict{String,Any}(
            "timezone" => Dict{String,Any}(
                "type" => "string",
                "description" => "Timezone name (e.g., 'UTC', 'America/New_York')"
            )
        )
    ))
    
    # Register time conversion tool
    register_tool!(server, "convert_time", Dict{String,Any}(
        "name" => "convert_time",
        "description" => "Convert time between timezones",
        "parameters" => Dict{String,Any}(
            "source_timezone" => Dict{String,Any}(
                "type" => "string",
                "description" => "Source timezone"
            ),
            "target_timezone" => Dict{String,Any}(
                "type" => "string",
                "description" => "Target timezone"
            ),
            "time" => Dict{String,Any}(
                "type" => "string",
                "description" => "Time to convert (ISO format)"
            )
        )
    ))
    
    server.tools["get_current_time"] = get_current_time
    server.tools["convert_time"] = convert_time
    server
end

"""
    get_current_time(params::Dict)

Get the current time in the specified timezone.
"""
function get_current_time(params::Dict)
    if !haskey(params, "timezone")
        throw(ArgumentError("Missing required parameter: timezone"))
    end
    tz_name = params["timezone"]
    local tz_val
    try
        tz_val = TimeZone(tz_name)
    catch e
        throw(ErrorException("Invalid timezone: $tz_name"))
    end
    current_time = now(tz_val)
    Dict(
        "time" => format(current_time, "yyyy-mm-dd HH:MM:SS"),
        "timezone" => string(tz_val),
        "is_dst" => current_time.zone isa VariableTimeZone ? isdst(current_time) : false
    )
end

"""
    convert_time(params::Dict)

Convert time between different timezones.
"""
function convert_time(params::Dict)
    # Validate required parameters
    for param in ["time", "source_timezone", "target_timezone"]
        if !haskey(params, param)
            throw(ArgumentError("Missing required parameter: $param"))
        end
    end
    
    time_str = params["time"]
    local source_tz_val, target_tz_val
    try
        source_tz_val = TimeZone(params["source_timezone"])
        target_tz_val = TimeZone(params["target_timezone"])
    catch e
        throw(ErrorException("Invalid timezone provided"))
    end
    
    # Parse and validate time format
    local dt
    try
        dt = DateTime(time_str, dateformat"yyyy-mm-ddTHH:MM:SS")
    catch e2
        throw(ArgumentError("Invalid time format. Expected format: YYYY-MM-DDTHH:MM:SS"))
    end
    
    # Create ZonedDateTime
    source_time = ZonedDateTime(dt, source_tz_val)
    target_time = astimezone(source_time, target_tz_val)
    
    # Calculate time difference
    diff_hours = round((target_time.utc_datetime - source_time.utc_datetime) / Hour(1), digits=2)
    
    Dict(
        "source" => Dict(
            "timezone" => string(source_tz_val),
            "time" => format(source_time, "yyyy-mm-dd HH:MM:SS"),
            "is_dst" => source_time.zone isa VariableTimeZone ? isdst(source_time) : false
        ),
        "target" => Dict(
            "timezone" => string(target_tz_val),
            "time" => format(target_time, "yyyy-mm-dd HH:MM:SS"),
            "is_dst" => target_time.zone isa VariableTimeZone ? isdst(target_time) : false
        ),
        "time_difference" => "$(diff_hours)h"
    )
end

end # module
