#!/usr/bin/env julia

using Pkg
Pkg.activate(@__DIR__)
# Check if the project is instantiated
if !isfile(joinpath(@__DIR__, "Manifest.toml"))
    @info "Instantiating project..."
    Pkg.instantiate()
end

using WeatherServer
using ModelContextProtocol

function main(args)
    # Run the weather server
    server = WeatherServer.create_weather_server()
    ModelContextProtocol.run_server(server)
end

@main