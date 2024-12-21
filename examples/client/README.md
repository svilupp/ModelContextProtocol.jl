# Example MCP Client

This example demonstrates how to use the ModelContextProtocol.jl package to create a client that connects to an MCP server.

## Usage

1. Start an MCP server (e.g., the time server example)
2. In another terminal, run this client:

```julia
using ExampleClient
ExampleClient.run_example()
```

The example will:
1. Connect to the server
2. Initialize the connection
3. List available tools and resources
4. Try to call the time tool if available
5. Clean up the connection

This demonstrates the basic workflow of an MCP client using the ModelContextProtocol.jl package.
