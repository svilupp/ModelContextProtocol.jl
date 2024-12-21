# Time server example implementation
export create_time_server, get_current_time, convert_time

using TimeZones
using Dates

# Import specific TimeZones functions
import TimeZones: TimeZone, ZonedDateTime, UTC, astimezone, isdst

"""
    create_time_server(name::String="time", version::String="0.1.0")

Create a new server instance with time conversion capabilities.
"""
function create_time_server(name::String="time", version::String="0.1.0")
    server = Server(name, version)
    register_tool!(server, "get_current_time", get_current_time)
    register_tool!(server, "convert_time", convert_time)
    server
end

"""
    get_current_time(params::Dict{String,Any})

Get the current time in the specified timezone.

Parameters:
- timezone (string): IANA timezone name (e.g., 'America/New_York', 'Europe/London')
"""
function get_current_time(params::Dict{String,Any})
    if !haskey(params, "timezone")
        throw(ArgumentError("Missing required parameter: timezone"))
    end

    timezone = params["timezone"]
    try
        tz = timezone == "UTC" ? FixedTimeZone("UTC") : TimeZone(timezone)
        now_utc = now(FixedTimeZone("UTC"))
        now_dt = DateTime(now_utc)
        now_tz = ZonedDateTime(now_dt, tz)
        
        Dict{String,Any}(
            "timezone" => string(timezone),
            "datetime" => Dates.format(now_tz, "yyyy-mm-ddTHH:MM:SSzzzz"),
            "is_dst" => safe_isdst(tz)
        )
    catch e
        if isa(e, ArgumentError) && occursin("Unknown time zone", e.msg)
            throw(ErrorException("Invalid timezone: $timezone"))
        else
            rethrow(e)
        end
    end
end

"""
    convert_time(params::Dict{String,Any})

Convert time between timezones.

Parameters:
- source_timezone (string): Source IANA timezone name
- time (string): Time in 24-hour format (HH:MM)
- target_timezone (string): Target IANA timezone name
"""
function convert_time(params::Dict{String,Any})
    # Validate required parameters
    required = ["source_timezone", "time", "target_timezone"]
    for param in required
        if !haskey(params, param)
            throw(ArgumentError("Missing required parameter: $param"))
        end
    end

    source_tz = params["source_timezone"]
    target_tz = params["target_timezone"]
    time_str = params["time"]

    # Parse time string (HH:MM) before timezone operations
    local hour_val, minute_val
    try
        hour_val, minute_val = parse.(Int, split(time_str, ":"))
    catch
        throw(ArgumentError("Invalid time format. Use HH:MM in 24-hour format"))
    end
    
    if hour_val < 0 || hour_val > 23 || minute_val < 0 || minute_val > 59
        throw(ArgumentError("Invalid time format. Use HH:MM in 24-hour format"))
    end

    # Parse source and target timezones
    local source, target
    try
        source = TimeZone(source_tz)
        target = TimeZone(target_tz)
    catch e
        throw(ErrorException("Invalid timezone: $(sprint(showerror, e))"))
    end

    try
        # Create ZonedDateTime for today with the given time
        today = Date(now())
        source_time = ZonedDateTime(DateTime(today, Time(hour_val, minute_val)), source)
        target_time = astimezone(source_time, target)

        # Calculate time difference in hours
        diff_hours = (hour_of_day(target_time) - hour_of_day(source_time)) +
                    (minute_of_hour(target_time) - minute_of_hour(source_time)) / 60.0
        
        # Format time difference with sign
        diff_str = diff_hours >= 0 ? "+$(diff_hours)h" : "$(diff_hours)h"

        Dict{String,Any}(
            "source" => Dict{String,Any}(
                "timezone" => string(source_tz),
                "datetime" => Dates.format(source_time, "yyyy-mm-ddTHH:MM:SSzzzz"),
                "is_dst" => safe_isdst(source)
            ),
            "target" => Dict{String,Any}(
                "timezone" => string(target_tz),
                "datetime" => Dates.format(target_time, "yyyy-mm-ddTHH:MM:SSzzzz"),
                "is_dst" => safe_isdst(target)
            ),
            "time_difference" => diff_str
        )
    catch e
        if isa(e, ArgumentError)
            throw(e)  # Preserve ArgumentError for invalid time format
        else
            throw(ErrorException("Time conversion failed: $(sprint(showerror, e))"))
        end
    end
end

# Helper functions for time components
hour_of_day(dt::ZonedDateTime) = hour(dt)
minute_of_hour(dt::ZonedDateTime) = minute(dt)

# Safe DST checking that handles both fixed and variable timezones
function safe_isdst(tz::TimeZone)
    if tz isa FixedTimeZone
        return false  # Fixed timezones never observe DST
    else
        # For variable timezones (like America/New_York)
        current = now(tz)
        # Get the current offset from the zone's offset field
        offset = current.zone.offset
        return TimeZones.isdst(offset)  # Check if current offset indicates DST
    end
end
