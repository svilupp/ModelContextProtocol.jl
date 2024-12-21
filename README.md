# ModelContextProtocol.jl

A minimal Julia implementation of the [Model Context Protocol](https://modelcontextprotocol.io/introduction) (MCP), providing a simple SDK for building MCP-compliant servers.

## Features

- JSON-RPC 2.0 compliant message handling
- Built-in support for tool registration and dynamic dispatch
- Example implementations:
  - Time Server: Timezone conversion and current time queries
  - Fetch Server: URL content retrieval
- Comprehensive test suite

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/svilupp/ModelContextProtocol.jl.git")
```

## Quick Start

### Creating a Simple Time Server

```julia
using ModelContextProtocol

# Create a time server
server = create_time_server()

# Server provides two tools:
# 1. get_current_time - Get current time in a specific timezone
params = Dict("timezone" => "America/New_York")
response = get_current_time(params)

# 2. convert_time - Convert time between timezones
params = Dict(
    "source_timezone" => "UTC",
    "time" => "14:30",
    "target_timezone" => "America/Los_Angeles"
)
response = convert_time(params)

# Run the server to handle JSON-RPC requests
run_server(server)
```

### Creating a Fetch Server

```julia
using ModelContextProtocol

# Create a fetch server
server = create_fetch_server()

# Server provides URL content retrieval
params = Dict(
    "url" => "https://example.com",
    "max_length" => 1000,  # Optional: limit content length
    "raw" => false        # Optional: convert HTML to markdown
)
response = fetch_url(params)

# Run the server
run_server(server)
```

## Protocol Overview

The Model Context Protocol (MCP) standardizes interactions between AI models and tools. This implementation follows the [core architecture](https://modelcontextprotocol.io/docs/concepts/architecture) using JSON-RPC 2.0 for message exchange.

### Core Components

1. Server
```julia
# Create and configure a server
server = Server("MyServer", "1.0.0")

# Register tools, prompts, and resources
register_tool!(server, "my_tool", params -> Dict("result" => "Hello!"))
register_prompt!(server, "greeting", "Say hello to {name}")
register_resource!(server, "config", Dict("timeout" => 30))

# Run the server
run_server(server)
```

2. Client
```julia
# Create a client
client = Client("MyClient")

# Initialize connection
initialize_client!(client)

# Send requests
response = send_request(client, "my_tool", Dict("param" => "value"))
```

## Contributing


Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
