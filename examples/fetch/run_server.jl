#!/usr/bin/env julia

using Pkg
Pkg.activate(@__DIR__)
# Check if the project is instantiated
if !isfile(joinpath(@__DIR__, "Manifest.toml"))
    @info "Instantiating project..."
    Pkg.instantiate()
end

using FetchServer
using ModelContextProtocol

function main(args)
    # Run the fetch server
    server = FetchServer.create_fetch_server()
    ModelContextProtocol.run_server(server)
end

@main