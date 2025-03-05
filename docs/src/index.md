```@meta
CurrentModule = ModelContextProtocol
```

# ModelContextProtocol.jl

A Julia implementation of the [Model Context Protocol](https://modelcontextprotocol.io/introduction) (MCP), providing an SDK for building MCP-compliant servers and clients that enable AI models to access external tools.

## Features

- JSON-RPC 2.0 compliant message handling
- Built-in support for tool registration and dynamic dispatch
- Simple API for creating MCP clients and servers

## Installation

The package is not yet registered, so you need to add it manually:

```julia
using Pkg
Pkg.add(url="https://github.com/svilupp/ModelContextProtocol.jl.git")
```

## Quick Start

### Using MCP Tools with Claude

To use MCP-enabled tools with Claude, you need to configure your Claude desktop application:

1. Add tool configurations to your Claude desktop config file:
   - macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - Windows: `%APPDATA%\Claude\claude_desktop_config.json`

For detailed installation and setup instructions, visit the [MCP Quickstart Guide](https://modelcontextprotocol.io/quickstart/user).

### Creating a MCP Server

```julia
using ModelContextProtocol

# Create a server
server = Server("MyServer", "1.0.0")

# Register a tool
register_tool!(server, "hello", 
    params -> Dict("result" => "Hello, $(get(params, "name", "World"))!"),
    Dict("type" => "object", "properties" => Dict("name" => Dict("type" => "string")))
)

# Run the server
run_server(server)
```

### Using the MCP Client

```julia
using ModelContextProtocol

# Create a client
client = Client()

# Connect to a server
connect!(client, io_connection) # Can be stdin, a socket, etc.
initialize!(client)

# List available tools
tools = list_tools(client)
println("Available tools: ", [tool["name"] for tool in tools])

# Call a tool
response = call_tool(client, "hello", Dict("name" => "Julia"))
```

## Included Example Tools

The package includes several example MCP-compliant tools:

### Time Server
Provides tools for timezone conversion and current time queries:
- `get_current_time`: Get the current time in a specific timezone
- `convert_time`: Convert time between different timezones

### Fetch Server
URL content retrieval with configurable options:
- `fetch`: Fetch content from URLs with options to limit content length and convert HTML to markdown

### Weather Server
Weather forecast information:
- `weather`: Get weather forecasts for locations using the National Weather Service API

### Translate Server
Language translation services:
- `translate_text`: Translate text between languages
- `detect_language`: Detect the language of provided text
- `get_language_info`: Get detailed information about a specific language

## Interactive Example Client

The package includes an interactive client example that demonstrates how to use the MCP tools:

```julia
# Navigate to the example client directory
cd("examples/client")

# Activate the project
using Pkg
Pkg.activate(".")
Pkg.instantiate()

# Run the example client with a server
using ExampleClient
ExampleClient.main("/path/to/server_script.jl")
```

The interactive client supports commands like:
- `get time utc`
- `convert time America/New_York Europe/Paris 2023-01-01T12:00:00`
- `get weather for New York`
- `fetch https://example.com`

## Development / Inspector

If you want to develop new servers or debug any existing ones, use the [Inspector](https://modelcontextprotocol.io/docs/tools/inspector).

Just launch it `npx @modelcontextprotocol/inspector`, open it in the browser and connect to your server to inspect it.

For local tools, you must provide them as an argument to the inspector, eg, 
`npx @modelcontextprotocol/inspector julia my_server/run_server.jl`

## Protocol Overview

The Model Context Protocol (MCP) standardizes interactions between AI models and tools. This implementation follows the [core architecture](https://modelcontextprotocol.io/docs/concepts/architecture) using JSON-RPC 2.0 for message exchange.

![Diagram](docs/src/assets/diagram.png)

### Core Components

1. **Server**: Registers and provides tools, prompts, and resources
2. **Client**: Discovers and calls tools exposed by MCP servers
3. **Transport**: Handles message passing between clients and servers

## License

This project is licensed under the MIT License - see the LICENSE file for details.