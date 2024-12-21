using Test
using ModelContextProtocol
using JSON

@testset "JSON-RPC Types" begin
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

        # Test request serialization
        req_dict = to_dict(req)
        @test req_dict["jsonrpc"] == "2.0"
        @test req_dict["method"] == "test_method"
        @test req_dict["params"]["key"] == "value"
        @test req_dict["id"] == 1
    end

    @testset "Response" begin
        # Test response with result
        resp_json = """
        {
            "jsonrpc": "2.0",
            "result": {"status": "success"},
            "id": 1
        }
        """
        resp = parse_response(resp_json)
        @test resp.result["status"] == "success"
        @test resp.id == 1

        # Test response serialization
        resp_dict = to_dict(resp)
        @test resp_dict["jsonrpc"] == "2.0"
        @test resp_dict["result"]["status"] == "success"
        @test resp_dict["id"] == 1
    end

    @testset "Error" begin
        # Test error with all fields
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
        err = parse_error(error_json)
        @test err.error["code"] == -32600
        @test err.error["message"] == "Invalid Request"
        @test err.error["data"]["details"] == "Method not found"
        @test err.id == 1

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

        # Test notification serialization
        notif_dict = to_dict(notif)
        @test notif_dict["jsonrpc"] == "2.0"
        @test notif_dict["method"] == "update"
        @test notif_dict["params"]["status"] == "running"
    end
end
