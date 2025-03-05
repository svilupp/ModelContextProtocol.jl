#!/usr/bin/env julia

using Pkg
Pkg.activate(@__DIR__)
# Check if the project is instantiated
if !isfile(joinpath(@__DIR__, "Manifest.toml"))
    @info "Instantiating project..."
    Pkg.instantiate()
end

using ModelContextProtocol
using FetchServer

# Create a server instance
server = create_fetch_server("fetch-server", "0.1.0")

# Start the server on stdin/stdout
ModelContextProtocol.serve(server, stdin, stdout)