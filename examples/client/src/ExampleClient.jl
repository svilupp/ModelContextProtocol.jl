module ExampleClient

using ModelContextProtocol
using JSON3

"""
    run_example(server_process=nothing)

Run an example client that connects to a server and demonstrates basic MCP operations.
If server_process is provided, the client will connect to that process.
Otherwise, it will expect a server running on stdin.
"""
function run_example(server_process = nothing)
    # Create a new client
    client = Client()

    # Connect to server
    if isnothing(server_process)
        # For manual connection to a running server via stdin
        connect!(client, stdin)
    else
        # Connect to the provided server process
        connect!(client, server_process)
    end

    try
        # Initialize connection
        initialize!(client)
        println("\nConnected to server!")
        println("Server: $(client.server_info["name"]) v$(client.server_info["version"])")

        # List available tools
        tools = list_tools(client)
        println("\nAvailable tools:")
        for tool in tools
            println("- $(tool["name"]): $(get(tool, "description", "No description"))")
        end

        # List available prompts and resources
        try
            prompts = list_prompts(client)
            if !isempty(prompts)
                println("\nAvailable prompts:")
                for prompt in prompts
                    println("- $(prompt["name"])")
                end
            end
        catch e
            # It's okay if this fails - the server might not support prompts
        end

        try
            resources = list_resources(client)
            if !isempty(resources)
                println("\nAvailable resources:")
                for resource in resources
                    println("- $(resource["name"])")
                end
            end
        catch e
            # It's okay if this fails - the server might not support resources
        end

        println("\nEnter commands or 'quit' to exit.")
        println("Example commands:")
        println("- get time utc")
        println("- convert time America/New_York Europe/Paris 2023-01-01T12:00:00")
        println("- get weather for New York")
        println("- fetch https://example.com")
        println("- help time-zones")

        while true
            print("\nCommand: ")
            cmd = readline()
            cmd == "quit" && break

            try
                if startswith(cmd, "get time")
                    # Time tool example
                    timezone = length(split(cmd)) > 2 ? split(cmd)[3] : "UTC"
                    result = call_tool(client, "get_current_time",
                        Dict{String, Any}("timezone" => timezone))

                    displayToolResponse(result)

                elseif startswith(cmd, "convert time") && length(split(cmd)) >= 5
                    # Time conversion example
                    parts = split(cmd)
                    source_tz = parts[3]
                    target_tz = parts[4]
                    time_str = parts[5]

                    result = call_tool(client,
                        "convert_time",
                        Dict{String, Any}(
                            "source_timezone" => source_tz,
                            "target_timezone" => target_tz,
                            "time" => time_str
                        ))

                    displayToolResponse(result)

                elseif startswith(cmd, "get weather")
                    # Weather tool example
                    location = join(split(cmd)[3:end], " ")
                    result = call_tool(
                        client, "weather", Dict{String, Any}("location" => location))

                    displayToolResponse(result)

                elseif startswith(cmd, "fetch")
                    # Fetch tool example
                    url = split(cmd)[2]
                    result = call_tool(client, "fetch", Dict{String, Any}("url" => url))

                    displayToolResponse(result)

                elseif startswith(cmd, "help") && length(split(cmd)) > 1
                    # Try to get a prompt or resource
                    topic = split(cmd)[2]

                    if topic == "time-zones" || topic == "timezones"
                        try
                            prompt = get_prompt(client, "time_zone_help")
                            if haskey(prompt, "content") &&
                               prompt["content"]["type"] == "text"
                                println("\n" * prompt["content"]["text"])
                            end
                        catch e
                            println("No help available for this topic")
                        end
                    else
                        println("No help available for this topic")
                    end

                else
                    println("Unknown command. Try 'get time utc', 'convert time America/New_York Europe/Paris 2023-01-01T12:00:00', or 'help time-zones'")
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

        # If we have a server process, make sure to close it
        if !isnothing(server_process)
            try
                kill(server_process)
            catch
                # It's okay if this fails - the process might already be closed
            end
        end
    end
end

"""
    run_with_fetch_server()

Run the example client with the fetch server.
"""
function run_with_fetch_server()
    # Find the path to the fetch server script
    script_dir = dirname(@__FILE__)
    repo_root = dirname(dirname(dirname(script_dir)))
    fetch_server_script = joinpath(repo_root, "examples", "fetch", "run_server.jl")

    if !isfile(fetch_server_script)
        println("Error: Fetch server script not found at expected path: $fetch_server_script")
        return 1
    end

    # Start the fetch server as a subprocess
    fetch_dir = dirname(fetch_server_script)
    server_cmd = `julia --project=$fetch_dir $fetch_server_script`
    server_process = open(server_cmd, "r+")

    # Run the client connected to the server process
    run_example(server_process)
    return 0
end

"""
    displayToolResponse(response::Dict{String,Any})

Display a tool response in a user-friendly format.
"""
function displayToolResponse(response::Dict{String, Any})
    # Check if this is a valid MCP response
    if !haskey(response, "content") || !isa(response["content"], Vector)
        println("Invalid response format")
        println(JSON3.write(response))
        return
    end

    # Check if there was an error
    if get(response, "isError", false)
        println("Error from server: $(get(response, "status", "unknown error"))")
        return
    end

    # Display each content item
    for item in response["content"]
        if !haskey(item, "type")
            continue
        end

        if item["type"] == "text"
            println("\n$(item["text"])")

        elseif item["type"] == "json"
            # For JSON, we'll print a more user-friendly representation
            println("\nJSON response:")
            prettyPrintJson(item["json"])

        elseif item["type"] == "html"
            println("\nHTML content:")
            println(ModelContextProtocol.html_to_markdown(item["html"]))

        elseif item["type"] == "image"
            println("\nImage URL: $(item["url"])")
            if haskey(item, "alt_text") && !isempty(item["alt_text"])
                println("Description: $(item["alt_text"])")
            end
        end
    end
end

"""
    prettyPrintJson(data::Any, indent::Int=0)

Pretty print a JSON object with indentation.
"""
function prettyPrintJson(data::Any, indent::Int = 0)
    spaces = " "^indent

    if isa(data, Dict)
        for (key, value) in data
            if isa(value, Dict) || isa(value, Vector)
                println("$(spaces)$(key):")
                prettyPrintJson(value, indent + 2)
            else
                println("$(spaces)$(key): $(value)")
            end
        end
    elseif isa(data, Vector)
        for (i, item) in enumerate(data)
            if isa(item, Dict) || isa(item, Vector)
                println("$(spaces)[$i]:")
                prettyPrintJson(item, indent + 2)
            else
                println("$(spaces)[$i]: $(item)")
            end
        end
    else
        println("$(spaces)$(data)")
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

    # Start the server as a subprocess
    server_cmd = `julia --project=$(dirname(dirname(server_script))) $server_script`
    server_process = open(server_cmd, "r+")

    # Run the client connected to the server process
    run_example(server_process)
    return 0
end

end # module
