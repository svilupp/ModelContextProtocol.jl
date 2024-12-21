module ModelContextProtocol

using JSON3
using Markdown

# Export types
export Request, AbstractResponse, SuccessResponse, ErrorResponse, Response
export Server, Client

# Export server functions
export create_server, handle_request, register_tool!
export get_capabilities, list_tools, call_tool
export html_to_markdown

# Core types and functionality
include("types.jl")
include("server.jl")
include("client.jl")

"""
    html_to_markdown(html::String)::String

Convert HTML content to Markdown format.
This is a simple implementation that handles basic HTML tags.
"""
function html_to_markdown(html::String)::String
    # Remove script, style tags and comments first
    html = replace(html, r"<script\b[^>]*>.*?</script>"s => "")
    html = replace(html, r"<style\b[^>]*>.*?</style>"s => "")
    html = replace(html, r"<!--.*?-->"s => "")
    
    # Helper function to process inline formatting
    function process_inline(content::AbstractString)::String
        content = replace(content, r"<strong[^>]*>(.*?)</strong>"s => s"**\1**")
        content = replace(content, r"<b[^>]*>(.*?)</b>"s => s"**\1**")
        content = replace(content, r"<em[^>]*>(.*?)</em>"s => s"*\1*")
        content = replace(content, r"<i[^>]*>(.*?)</i>"s => s"*\1*")
        content = replace(content, r"<code[^>]*>(.*?)</code>"s => s"`\1`")
        content = replace(content, r"<a[^>]*href=\"([^\"]+)\"[^>]*>(.*?)</a>"s => s"[\2](\1)")
        content = replace(content, r"<br[^>]*>"s => "\n")
        # Remove any remaining inline HTML tags
        content = replace(content, r"<[^>]+>" => "")
        strip(content)
    end
    
    # Helper function to convert a single HTML element to markdown
    function convert_element(element::AbstractString)::String
        if occursin(r"<h1[^>]*>", element)
            content = match(r"<h1[^>]*>(.*?)</h1>"s, element).captures[1]
            return "# " * process_inline(content) * "\n"
        elseif occursin(r"<h2[^>]*>", element)
            content = match(r"<h2[^>]*>(.*?)</h2>"s, element).captures[1]
            return "## " * process_inline(content) * "\n"
        elseif occursin(r"<h3[^>]*>", element)
            content = match(r"<h3[^>]*>(.*?)</h3>"s, element).captures[1]
            return "### " * process_inline(content) * "\n"
        elseif occursin(r"<p[^>]*>", element)
            content = match(r"<p[^>]*>(.*?)</p>"s, element).captures[1]
            return process_inline(content) * "\n\n"
        elseif occursin(r"<ul[^>]*>", element)
            content = match(r"<ul[^>]*>(.*?)</ul>"s, element).captures[1]
            items = [process_inline(item.captures[1]) for item in eachmatch(r"<li[^>]*>(.*?)</li>"s, content)]
            return isempty(items) ? "" : "\n" * join(map(i -> "* " * i, items), "\n") * "\n"
        elseif occursin(r"<ol[^>]*>", element)
            content = match(r"<ol[^>]*>(.*?)</ol>"s, element).captures[1]
            items = [process_inline(item.captures[1]) for item in eachmatch(r"<li[^>]*>(.*?)</li>"s, content)]
            return isempty(items) ? "" : "\n" * join(map((i, item) -> "$i. " * item, 1:length(items), items), "\n") * "\n"
        else
            return process_inline(element)
        end
    end
    
    # Process block elements
    md = ""
    for element in eachmatch(r"<(?:h[1-3]|p|ul|ol)[^>]*>.*?</(?:h[1-3]|p|ul|ol)>"s, html)
        md *= convert_element(element.match)
    end
    
    # If no block elements were found, just process the text
    if isempty(md)
        md = process_inline(html)
    end
    
    # Clean up whitespace
    md = replace(md, r"\n{3,}" => "\n\n")
    strip(md)
end

end # module
