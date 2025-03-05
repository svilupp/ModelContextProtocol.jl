module ModelContextProtocol

using JSON3
using Markdown
using Base.Threads: @spawn

# Export error code constants
export ErrorCodes

# Export main types
export Request, AbstractResponse, SuccessResponse, ErrorResponse, Notification
export Server, Client

# Export server public API
export register_tool!, register_prompt!, register_resource!
export run_server

# Export client public API
export connect!, initialize!, close
export list_tools, list_resources, list_prompts
export call_tool, extract_content, get_resource, get_prompt

# Export content creation helpers (for tool implementers)
export create_tool_response
export create_text_content, create_json_content, create_html_content, create_image_content

# Export utility functions
export html_to_markdown

# Core types and functionality
include("types.jl")
include("server.jl")
include("client.jl")
include("utils.jl")

end # module
