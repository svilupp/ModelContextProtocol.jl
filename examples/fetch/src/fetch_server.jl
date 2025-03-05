#!/usr/bin/env julia

using ModelContextProtocol
using FetchServer

# Create a server instance
server = create_fetch_server("fetch-server", "0.1.0")

# Start the server on stdin/stdout
ModelContextProtocol.serve(server, stdin, stdout)