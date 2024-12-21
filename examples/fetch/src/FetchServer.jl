module FetchServer

using HTTP
using ModelContextProtocol

export create_fetch_server, fetch_url, html_to_markdown

"""
    create_fetch_server(name::String="fetch", version::String="0.1.0")

Create a new server instance with URL fetching capabilities.
"""
function create_fetch_server(name::String="fetch", version::String="0.1.0")
    server = Server(name, version)
    register_tool!(server, "fetch", Dict{String,Any}(
        "name" => "fetch",
        "description" => "Fetch content from a URL",
        "parameters" => Dict{String,Any}(
            "url" => Dict{String,Any}(
                "type" => "string",
                "description" => "URL to fetch"
            ),
            "max_length" => Dict{String,Any}(
                "type" => "integer",
                "description" => "Maximum length of content to return",
                "optional" => true
            ),
            "raw" => Dict{String,Any}(
                "type" => "boolean",
                "description" => "Return raw HTML instead of markdown",
                "optional" => true,
                "default" => false
            )
        )
    ))
    server.tools["fetch"] = fetch_url
    server
end

"""
    fetch_url(params::Dict)

Fetch content from a URL and convert it to markdown if specified.
"""
function fetch_url(params::Dict)
    if !haskey(params, "url")
        throw(ArgumentError("Missing required parameter: url"))
    end
    url = params["url"]
    raw = get(params, "raw", false)
    max_length = get(params, "max_length", nothing)
    
    response = HTTP.get(url)
    
    # Get content type from headers
    content_type = HTTP.header(response, "Content-Type", "text/html")
    
    # Only convert HTML content
    if occursin("text/html", content_type)
        content = String(response.body)
        if !raw
            # Clean up potential encoding issues
            content = replace(content, r"<meta[^>]*charset=[^>]*>" => "")
            content = ModelContextProtocol.html_to_markdown(content)
        end
    else
        # For non-HTML content, just return as text
        content = String(response.body)
    end
    
    if !isnothing(max_length)
        content = first(content, max_length)
    end
    
    Dict(
        "content" => content,
        "url" => url,
        "length" => length(content)
    )
end

end # module
