module TimeServer

using Dates: DateTime, @dateformat_str, Millisecond, Hour, format
using TimeZones: TimeZone, ZonedDateTime, now, astimezone, hour, isdst, VariableTimeZone
using ModelContextProtocol

import ModelContextProtocol: Server, register_tool!, Request, SuccessResponse, handle_request, create_text_content, create_json_content, create_tool_response

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
            "type" => "object",
            "properties" => Dict{String,Any}(
                "timezone" => Dict{String,Any}(
                    "type" => "string",
                    "description" => "Timezone name (e.g., 'UTC', 'America/New_York')"
                )
            ),
            "required" => ["timezone"]
        )
    ))
    
    # Register time conversion tool
    register_tool!(server, "convert_time", Dict{String,Any}(
        "name" => "convert_time",
        "description" => "Convert time between timezones",
        "parameters" => Dict{String,Any}(
            "type" => "object",
            "properties" => Dict{String,Any}(
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
            ),
            "required" => ["source_timezone", "target_timezone", "time"]
        )
    ))
    
    # Register a sample prompt
    register_prompt!(server, "time_zone_help", Dict{String,Any}(
        "type" => "text",
        "text" => """
        # Time Zone Help
        
        Time zones are regions of the globe that observe a uniform standard time for legal, commercial, and social purposes.
        
        Common time zones include:
        - UTC (Coordinated Universal Time)
        - America/New_York (Eastern Time)
        - America/Los_Angeles (Pacific Time)
        - Europe/London (British Time)
        - Asia/Tokyo (Japan Time)
        """
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
    
    content = [
        create_json_content(Dict{String,Any}(
            "time" => format(current_time, "yyyy-mm-dd HH:MM:SS"),
            "timezone" => string(tz_val),
            "is_dst" => current_time.zone isa VariableTimeZone ? isdst(current_time) : false
        )),
        create_text_content(
            "The current time in $(tz_name) is $(format(current_time, "yyyy-mm-dd HH:MM:SS"))"
        )
    ]
    
    create_tool_response(content)
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
    
    result = Dict{String,Any}(
        "source" => Dict{String,Any}(
            "timezone" => string(source_tz_val),
            "time" => format(source_time, "yyyy-mm-dd HH:MM:SS"),
            "is_dst" => source_time.zone isa VariableTimeZone ? isdst(source_time) : false
        ),
        "target" => Dict{String,Any}(
            "timezone" => string(target_tz_val),
            "time" => format(target_time, "yyyy-mm-dd HH:MM:SS"),
            "is_dst" => target_time.zone isa VariableTimeZone ? isdst(target_time) : false
        ),
        "time_difference" => "$(diff_hours)h"
    )
    
    # Create a human-readable text response too
    text_response = """
    Time Conversion:
    - $(format(source_time, "yyyy-mm-dd HH:MM:SS")) in $(params["source_timezone"])
    - $(format(target_time, "yyyy-mm-dd HH:MM:SS")) in $(params["target_timezone"])
    - Difference: $(diff_hours) hours
    """
    
    content = [
        create_json_content(result),
        create_text_content(text_response)
    ]
    
    create_tool_response(content)
end

end # module
