# Example MCP Client

This example demonstrates how to use the ModelContextProtocol.jl package to create a client that connects to an MCP server.

## Usage

### Method 1: Connect to the Fetch Server

The simplest way to run the example is to use the built-in fetch server:

```julia
using ExampleClient
ExampleClient.run_with_fetch_server()
```

This will:
1. Launch the fetch server as a subprocess
2. Connect the client to the server
3. Allow you to interact with the fetch server

### Method 2: Connect to a Running Server

If you already have a server running:

1. Start an MCP server (e.g., the time server example)
2. In another terminal, run this client:

```julia
using ExampleClient
ExampleClient.run_example()
```

### Method 3: Start a Server from the Command Line

You can also specify a server script to launch:

```bash
julia --project=. -e 'using ExampleClient; ExampleClient.main()' /path/to/server_script.jl
```

## What the Example Does

The example will:
1. Connect to the server
2. Initialize the connection
3. List available tools and resources
4. Allow you to interact with the server via a command interface
5. Clean up the connection when you're done

This demonstrates the basic workflow of an MCP client using the ModelContextProtocol.jl package.
