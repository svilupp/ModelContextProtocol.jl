# Fetch server example implementation
export create_fetch_server, fetch_url, html_to_markdown

using HTTP
using JSON

"""
    create_fetch_server(name::String="fetch", version::String="0.1.0")

Create a new server instance with URL fetching capabilities.
"""
function create_fetch_server(name::String="fetch", version::String="0.1.0")
    server = Server(name, version)
    register_tool(server, "fetch", fetch_url)
    server
end

"""
    fetch_url(params::Dict{String,Any})

Fetch content from a URL with optional parameters:
- url (string, required): URL to fetch
- max_length (integer, optional): Maximum number of characters to return (default: 5000)
- start_index (integer, optional): Start content from this character index (default: 0)
- raw (boolean, optional): Get raw content without markdown conversion (default: false)
"""
function fetch_url(params::Dict{String,Any})
    # Validate required parameters
    if !haskey(params, "url")
        throw(ArgumentError("Missing required parameter: url"))
    end

    url = params["url"]
    max_length = get(params, "max_length", 5000)
    start_index = get(params, "start_index", 0)
    raw = get(params, "raw", false)

    # Fetch the content
    try
        response = HTTP.get(url)
        content = String(response.body)

        # Convert to markdown if needed
        if !raw
            content = html_to_markdown(content)
        end

        # Apply chunking
        if start_index > 0
            content = content[min(start_index + 1, end):end]
        end
        if max_length > 0
            content = content[1:min(max_length, length(content))]
        end

        return Dict{String,Any}(
            "content" => content,
            "url" => url,
            "length" => length(content)
        )
    catch e
        throw(ErrorException("Failed to fetch URL: $(sprint(showerror, e))"))
    end
end

"""
    html_to_markdown(html::String)

Convert HTML content to simplified markdown/plain text.
This is a minimal implementation that handles basic HTML cleanup.
"""
function html_to_markdown(html::String)
    # Remove script and style tags and their content
    html = replace(html, r"<script[^>]*>.*?</script>"s => "")
    html = replace(html, r"<style[^>]*>.*?</style>"s => "")
    
    # Convert common HTML elements to markdown
    html = replace(html, r"<h[1-6][^>]*>(.*?)</h[1-6]>"s => s"\1\n")
    html = replace(html, r"<p[^>]*>(.*?)</p>"s => s"\1\n\n")
    html = replace(html, r"<br[^>]*>"s => "\n")
    html = replace(html, r"<li[^>]*>(.*?)</li>"s => s"* \1\n")
    
    # Remove remaining HTML tags
    html = replace(html, r"<[^>]+>" => "")
    
    # Decode HTML entities
    html = replace(html, "&nbsp;" => " ")
    html = replace(html, "&amp;" => "&")
    html = replace(html, "&lt;" => "<")
    html = replace(html, "&gt;" => ">")
    html = replace(html, "&quot;" => "\"")
    
    # Clean up whitespace
    html = replace(html, r"\n\s*\n\s*\n"s => "\n\n")
    strip(html)
end
