using Test
using ModelContextProtocol
using HTTP
using JSON3
using FetchServer

@testset "Fetch Server" begin
    @testset "Server Creation" begin
        server = create_fetch_server()
        @test server isa ModelContextProtocol.Server
        @test length(server.tools) == 1  # Should have the fetch tool registered
    end

    @testset "HTML to Markdown Conversion" begin
        html = """
        <h1>Title</h1>
        <ul>
            <li>Item 1</li>
            <li>Item 2</li>
        </ul>
        <ol>
            <li>First</li>
            <li>Second</li>
        </ol>
        """
        md = html_to_markdown(html)
        @test occursin("# Title", md)
        @test occursin("* Item 1", md)
        @test occursin("* Item 2", md)
        @test occursin("1. First", md)
        @test occursin("2. Second", md)
    end

    @testset "Fetch URL Parameters" begin
        server = create_fetch_server()
        @test haskey(server.tools, "fetch")
        @test haskey(server.metadata, "fetch")
        tool_spec = server.metadata["fetch"]
        @test tool_spec["name"] == "fetch"
        @test haskey(tool_spec["parameters"], "url")
        @test haskey(tool_spec["parameters"], "max_length")
        @test haskey(tool_spec["parameters"], "raw")
    end

    @testset "Fetch Integration" begin
        server = create_fetch_server()

        # Test with a known URL
        test_url = "https://example.com"
        response = HTTP.get(test_url)
        content = String(response.body)

        result = ModelContextProtocol.call_tool(server, "fetch", Dict{String,Any}(
            "url" => test_url,
            "max_length" => 1000
        ))

        @test result isa Dict{String,Any}
        @test haskey(result, "content")
        @test length(result["content"]) <= 1000
    end
end
