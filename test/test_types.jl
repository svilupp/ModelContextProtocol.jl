using ModelContextProtocol
# Import internal functions that we need to test directly
using ModelContextProtocol: parse_request, parse_response, parse_notification,
                            to_dict, create_error_response, create_parse_error,
                            create_method_not_found_error, ErrorCodes,
                            create_text_content, create_json_content, create_html_content,
                            create_image_content, create_tool_response

@testset "Request" begin
    # Test request with all fields
    req_json = """
    {
        "jsonrpc": "2.0",
        "method": "test_method",
        "params": {"key": "value"},
        "id": 1
    }
    """
    req = parse_request(req_json)
    @test req.method == "test_method"
    @test req.params["key"] == "value"
    @test req.id == 1

    # Test request without params
    req_json_no_params = """
    {
        "jsonrpc": "2.0",
        "method": "test_method",
        "id": "abc"
    }
    """
    req_no_params = parse_request(req_json_no_params)
    @test req_no_params.method == "test_method"
    @test req_no_params.params === nothing
    @test req_no_params.id == "abc"

    # Test invalid request (missing jsonrpc field)
    req_json_invalid = """
    {
        "method": "test_method",
        "params": {"key": "value"},
        "id": 1
    }
    """
    @test_throws ErrorException parse_request(req_json_invalid)

    # Test request serialization
    req_dict = to_dict(req)
    @test req_dict["jsonrpc"] == "2.0"
    @test req_dict["method"] == "test_method"
    @test req_dict["params"]["key"] == "value"
    @test req_dict["id"] == 1
end

@testset "Response" begin
    # Test success response
    resp_json = """
    {
        "jsonrpc": "2.0",
        "result": {"status": "success"},
        "id": 1
    }
    """
    resp = parse_response(resp_json)
    @test resp isa SuccessResponse
    @test resp.result["status"] == "success"
    @test resp.id == 1

    # Test error response
    error_json = """
    {
        "jsonrpc": "2.0",
        "error": {
            "code": -32600,
            "message": "Invalid Request",
            "data": {"details": "Method not found"}
        },
        "id": 1
    }
    """
    err_resp = parse_response(error_json)
    @test err_resp isa ErrorResponse
    @test err_resp.error["code"] == -32600
    @test err_resp.error["message"] == "Invalid Request"
    @test err_resp.id == 1

    # Test invalid response (missing jsonrpc field)
    resp_json_invalid = """
    {
        "result": {"status": "success"},
        "id": 1
    }
    """
    @test_throws ErrorException parse_response(resp_json_invalid)

    # Test response serialization
    resp_dict = to_dict(resp)
    @test resp_dict["jsonrpc"] == "2.0"
    @test resp_dict["result"]["status"] == "success"
    @test resp_dict["id"] == 1
end

@testset "Error Responses" begin
    # Test error with all fields
    err = create_error_response(
        -32600, "Invalid Request", 1, Dict("details" => "Method not found"))
    @test err.error["code"] == -32600
    @test err.error["message"] == "Invalid Request"
    @test err.error["data"]["details"] == "Method not found"
    @test err.id == 1

    # Test standard error functions
    parse_err = create_parse_error(2, "JSON parse error")
    @test parse_err.error["code"] == ErrorCodes.PARSE_ERROR
    @test parse_err.error["message"] == "Parse error"
    @test parse_err.error["data"]["details"] == "JSON parse error"
    @test parse_err.id == 2

    method_err = create_method_not_found_error(3, "test_method")
    @test method_err.error["code"] == ErrorCodes.METHOD_NOT_FOUND
    @test method_err.error["message"] == "Method not found"
    @test method_err.id == 3

    # Test error serialization
    err_dict = to_dict(err)
    @test err_dict["jsonrpc"] == "2.0"
    @test err_dict["error"]["code"] == -32600
    @test err_dict["error"]["message"] == "Invalid Request"
    @test err_dict["error"]["data"]["details"] == "Method not found"
    @test err_dict["id"] == 1
end

@testset "Notification" begin
    # Test notification with params
    notif_json = """
    {
        "jsonrpc": "2.0",
        "method": "update",
        "params": {"status": "running"}
    }
    """
    notif = parse_notification(notif_json)
    @test notif.method == "update"
    @test notif.params["status"] == "running"

    # Test notification without params
    notif_json_no_params = """
    {
        "jsonrpc": "2.0",
        "method": "heartbeat"
    }
    """
    notif_no_params = parse_notification(notif_json_no_params)
    @test notif_no_params.method == "heartbeat"
    @test notif_no_params.params === nothing

    # Test invalid notification (with id)
    notif_json_invalid = """
    {
        "jsonrpc": "2.0",
        "method": "update",
        "params": {"status": "running"},
        "id": 1
    }
    """
    @test_throws ErrorException parse_notification(notif_json_invalid)

    # Test notification serialization
    notif_dict = to_dict(notif)
    @test notif_dict["jsonrpc"] == "2.0"
    @test notif_dict["method"] == "update"
    @test notif_dict["params"]["status"] == "running"
end

@testset "Tool Response Helpers" begin
    # Test content creation helpers
    text_content = create_text_content("Hello world")
    @test text_content["type"] == "text"
    @test text_content["text"] == "Hello world"

    json_content = create_json_content(Dict("key" => "value"))
    @test json_content["type"] == "json"
    @test json_content["json"]["key"] == "value"

    html_content = create_html_content("<p>Hello</p>")
    @test html_content["type"] == "html"
    @test html_content["html"] == "<p>Hello</p>"

    image_content = create_image_content("https://example.com/image.jpg", "Test image")
    @test image_content["type"] == "image"
    @test image_content["url"] == "https://example.com/image.jpg"
    @test image_content["alt_text"] == "Test image"

    # Test tool response creation
    content = [text_content, json_content]
    response = create_tool_response(content)
    @test response["content"] == content
    @test response["isError"] == false
    @test !haskey(response, "status")

    error_response = create_tool_response(content, true, "failed")
    @test error_response["content"] == content
    @test error_response["isError"] == true
    @test error_response["status"] == "failed"
end