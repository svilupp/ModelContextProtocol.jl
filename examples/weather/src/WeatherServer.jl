module WeatherServer

using ModelContextProtocol
using HTTP
using JSON3

import ModelContextProtocol: Server, register_tool!, Request, SuccessResponse, handle_request, list_tools, list_resources

export create_weather_server, forecast_tool, list_tools, list_resources

const NWS_API_BASE = "https://api.weather.gov"
const USER_AGENT = "ModelContextProtocol.jl/0.1.0"

"""
    create_weather_server()

Create a new MCP-compliant weather server with forecast tool.
"""
function create_weather_server()
    server = Server("weather_server")
    
    # Register the forecast tool with its schema
    register_tool!(server, 
        "get-forecast",
        forecast_tool,
        Dict{String,Any}(
            "name" => "get-forecast",
            "description" => "Get weather forecast for a location",
            "inputSchema" => Dict{String,Any}(
                "type" => "object",
                "properties" => Dict{String,Any}(
                    "latitude" => Dict{String,Any}(
                        "type" => "number",
                        "description" => "Latitude of the location"
                    ),
                    "longitude" => Dict{String,Any}(
                        "type" => "number",
                        "description" => "Longitude of the location"
                    )
                ),
                "required" => ["latitude", "longitude"]
            )
        )
    )
    return server
end

"""
    make_nws_request(url::String)

Make a request to the NWS API with proper headers.
"""
function make_nws_request(url::String)
    try
        response = HTTP.get(url, ["User-Agent" => USER_AGENT])
        return JSON3.read(String(response.body))
    catch e
        @warn "Failed to fetch data from NWS API" exception=e
        return nothing
    end
end

"""
    forecast_tool(params::Dict{String,Any})::Dict{String,Any}

Get weather forecast for a location using NWS API.
Returns a formatted forecast response following MCP specification.
"""
function forecast_tool(params::Dict{String,Any})::Dict{String,Any}
    # Validate and parse coordinates
    try
        latitude = Float64(params["latitude"])
        longitude = Float64(params["longitude"])
        
        # Basic coordinate validation
        if !(-90 ≤ latitude ≤ 90) || !(-180 ≤ longitude ≤ 180)
            return Dict{String,Any}(
                "content" => [Dict{String,Any}(
                    "type" => "text",
                    "text" => "Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180."
                )],
                "isError" => true
            )
        end
    catch e
        return Dict{String,Any}(
            "content" => [Dict{String,Any}(
                "type" => "text",
                "text" => "Invalid coordinates. Please provide valid numbers for latitude and longitude."
            )],
            "isError" => true
        )
    end

    # Get grid point data
    points_url = "$(NWS_API_BASE)/points/$(latitude),$(longitude)"
    points_data = make_nws_request(points_url)
    
    if isnothing(points_data)
        return Dict{String,Any}(
            "content" => [Dict{String,Any}(
                "type" => "text",
                "text" => "Failed to retrieve grid point data. This location may not be supported by the NWS API (only US locations are supported)."
            )],
            "isError" => true
        )
    end

    # Extract forecast URL and get forecast data
    forecast_url = get(points_data.properties, :forecast, nothing)
    if isnothing(forecast_url)
        return Dict{String,Any}(
            "content" => [Dict{String,Any}(
                "type" => "text",
                "text" => "Failed to get forecast URL from grid point data"
            )],
            "isError" => true
        )
    end

    forecast_data = make_nws_request(forecast_url)
    if isnothing(forecast_data)
        return Dict{String,Any}(
            "content" => [Dict{String,Any}(
                "type" => "text",
                "text" => "Failed to retrieve forecast data"
            )],
            "isError" => true
        )
    end

    # Format forecast periods
    periods = get(forecast_data.properties, :periods, [])
    if isempty(periods)
        return Dict{String,Any}(
            "content" => [Dict{String,Any}(
                "type" => "text",
                "text" => "No forecast periods available"
            )],
            "isError" => true
        )
    end

    # Format forecast text
    formatted_forecast = []
    for period in periods[1:3]  # Only show next 3 periods for brevity
        push!(formatted_forecast, """
            $(get(period, :name, "Unknown")):
            Temperature: $(get(period, :temperature, "Unknown"))°$(get(period, :temperatureUnit, "F"))
            Wind: $(get(period, :windSpeed, "Unknown")) $(get(period, :windDirection, ""))
            $(get(period, :shortForecast, "No forecast available"))
            ---""")
    end

    forecast_text = """
        Forecast for $(latitude), $(longitude):

        $(join(formatted_forecast, "\n"))
        """

    return Dict{String,Any}(
        "content" => [Dict{String,Any}(
            "type" => "text",
            "text" => forecast_text
        )],
        "isError" => false
    )
end

"""
    list_tools(server::Server)

List all available tools in the weather server.
"""
function list_tools(server::Server)
    tools = Dict{String,Any}[]
    for (name, metadata) in server.metadata
        push!(tools, Dict{String,Any}(
            "name" => name,
            "description" => get(metadata, "description", "No description available"),
            "parameters" => get(metadata, "inputSchema", Dict{String,Any}())
        ))
    end
    return Dict{String,Any}(
        "tools" => tools
    )
end

"""
    list_resources(server::Server)

List all available resources in the weather server.
Currently returns an empty list as no resources are implemented.
"""
function list_resources(server::Server)
    return Dict{String,Any}(
        "resources" => Dict{String,Any}[]
    )
end

end # module
