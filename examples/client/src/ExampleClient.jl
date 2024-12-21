module ExampleClient

using ModelContextProtocol
using JSON3

"""
    run_example()

Run an example client that connects to a server and demonstrates basic MCP operations.
"""
function run_example()
    # Create a new client
    client = Client()
    
    # Connect to server (using stdin/stdout for this example)
    connect!(client, stdin)
    
    try
        # Initialize connection
        initialize!(client)
        println("\nConnected to server!")
        
        # List available tools
        tools = list_tools(client)
        println("\nAvailable tools:")
        for tool in tools
            println("- $(tool["name"]): $(get(tool, "description", "No description"))")
        end
        
        println("\nEnter commands or 'quit' to exit.")
        println("Example commands:")
        println("- get time utc")
        println("- get weather for New York")
        println("- fetch https://example.com")
        
        while true
            print("\nCommand: ")
            cmd = readline()
            cmd == "quit" && break
            
            try
                if startswith(cmd, "get time")
                    # Time tool example
                    timezone = length(split(cmd)) > 2 ? split(cmd)[3] : "UTC"
                    result = call_tool(client, "time", Dict{String,Any}("timezone" => timezone))
                    println("Current time ($(timezone)): $(result["time"])")
                    
                elseif startswith(cmd, "get weather")
                    # Weather tool example
                    location = join(split(cmd)[3:end], " ")
                    result = call_tool(client, "weather", Dict{String,Any}("location" => location))
                    println("Weather for $(location):")
                    println("Temperature: $(get(result, "temperature", "N/A"))°C")
                    println("Conditions: $(get(result, "conditions", "N/A"))")
                    
                elseif startswith(cmd, "fetch")
                    # Fetch tool example
                    url = split(cmd)[2]
                    result = call_tool(client, "fetch", Dict{String,Any}("url" => url))
                    println("\nContent from $(url):")
                    println(result["content"])
                    
                else
                    println("Unknown command. Try 'get time utc', 'get weather for New York', or 'fetch https://example.com'")
                end
                
            catch e
                println("Error executing command: ", e)
            end
        end
        
    catch e
        println("Error: ", e)
    finally
        # Clean up
        close(client)
    end
end

"""
    main()

Entry point for running the example client from the command line.
"""
function main()
    if length(ARGS) < 1
        println("Usage: julia --project=. -e 'using ExampleClient; ExampleClient.main()' <server_script>")
        return 1
    end
    
    server_script = ARGS[1]
    if !isfile(server_script)
        println("Error: Server script '$(server_script)' not found")
        return 1
    end
    
    run_example()
    return 0
end

end # module
