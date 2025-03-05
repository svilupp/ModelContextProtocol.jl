using FetchServer
using ModelContextProtocol
# Import specific functions for direct use
import FetchServer: fetch_url
using ModelContextProtocol: html_to_markdown

@testset "Fetch Server" begin
    @testset "Server Creation" begin
        server = create_fetch_server("test_fetch")
        @test server.name == "test_fetch"
        @test haskey(server.tools, "fetch")
    end

    @testset "HTML to Markdown Conversion" begin
        html = """
        <html>
            <head>
                <style>body { color: red; }</style>
                <script>alert('test');</script>
            </head>
            <body>
                <h1>Title</h1>
                <p>Paragraph with <b>bold</b> text</p>
                <ul>
                    <li>Item 1</li>
                    <li>Item 2</li>
                </ul>
            </body>
        </html>
        """
        markdown = ModelContextProtocol.html_to_markdown(html)
        @test !contains(markdown, "<style>")
        @test !contains(markdown, "<script>")
        @test contains(markdown, "Title")
        @test contains(markdown, "Paragraph with **bold** text")
        @test contains(markdown, "* Item 1")
        @test contains(markdown, "* Item 2")
    end

    @testset "Fetch URL Parameters" begin
        # Test missing URL
        @test_throws ArgumentError fetch_url(Dict{String, Any}())

        # Test with all parameters
        params = Dict{String, Any}(
            "url" => "https://example.com",
            "max_length" => 100,
            "start_index" => 10,
            "raw" => true
        )
        @test haskey(params, "url")
        @test params["max_length"] == 100
        @test params["start_index"] == 10
        @test params["raw"] == true
    end

    @testset "Fetch Integration" begin
        server = create_fetch_server()

        # Test with httpbin.org (reliable test endpoint)
        params = Dict{String, Any}(
            "url" => "https://httpbin.org/html",
            "max_length" => 100
        )

        result = server.tools["fetch"](params)
        @test haskey(result, "content")
        
        # Content is now an array of content items as per MCP
        @test isa(result["content"], Vector)
        
        # Extract text content if available
        text_content = nothing
        for item in result["content"]
            if item["type"] == "text"
                text_content = item["text"] 
                break
            end
        end
        
        # At least one content item should be present
        @test length(result["content"]) > 0
    end
end
