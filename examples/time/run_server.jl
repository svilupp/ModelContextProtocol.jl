#!/usr/bin/env julia

using Pkg
Pkg.activate(@__DIR__)
# Check if the project is instantiated
if !isfile(joinpath(@__DIR__, "Manifest.toml"))
    @info "Instantiating project..."
    Pkg.instantiate()
end

using TimeServer
using ModelContextProtocol

function main(args)
    # Run the time server
    server = TimeServer.create_time_server()
    ModelContextProtocol.run_server(server)
end

@main