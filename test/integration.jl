#__ integration

const headers = [
    "User-Agent" => "EasyCurl.jl",
    "Content-Type" => "application/json"
]

const query = Dict{String,Any}(
    "echo" => "你好嗎"
)

const payload = "echo=hello"

@testset "HTTP Requests" begin
    # Test for nonexistent host error
    @testset "Nonexistent host error" begin
        @test_throws "CurlError: Couldn't resolve host name" http_get(
            "https://bar-foo.foo/get",
            read_timeout = 30,
            verbose = true,
        )
    end

    # Test for GET request
    @testset "GET request" begin
        response = http_get("httpbin.org/get", query = query, read_timeout = 30)
        @test http_status(response) == 200
        body = parse_json(http_body(response))
        @test body["args"] == query
        @test body["url"] == "http://httpbin.org/get?echo=你好嗎"
    end

    # Test for HEAD request
    @testset "HEAD request" begin
        response = http_head(
            "httpbin.org/get",
            headers = headers,
            read_timeout = 30,
            verbose = true,
        )
        @test http_status(response) == 200
        @test isempty(http_body(response))
    end

    # Test for POST request
    @testset "POST request" begin
        response = http_post(
            "httpbin.org/post",
            headers = headers,
            body = payload,
            read_timeout = 30,
            verbose = true,
        )
        @test http_status(response) == 200
        body = parse_json(http_body(response))
        @test body["data"] == payload
    end

    # Test for PUT request
    @testset "PUT request" begin
        response = http_put(
            "httpbin.org/put",
            headers = headers,
            body = payload,
            read_timeout = 30,
            verbose = true,
        )
        @test http_status(response) == 200
        body = parse_json(http_body(response))
        @test body["data"] == payload
    end

    # Test for PATCH request
    @testset "PATCH request" begin
        response = http_patch(
            "httpbin.org/patch",
            headers = headers,
            query = query,
            body = payload,
            read_timeout = 30,
            verbose = true,
        )
        @test http_status(response) == 200
        body = parse_json(http_body(response))
        @test body["data"] == payload
    end

    # Test for DELETE request
    @testset "DELETE request" begin
        response = http_delete(
            "httpbin.org/delete",
            headers = headers,
            read_timeout = 30,
            verbose = true,
        )
        @test http_status(response) == 200
    end
end

@testset verbose = true "Optional interface" begin
    server_setup = quote
        using Sockets

        port_hint = 9000 + (getpid() % 1000)
        port::UInt64, uv_server = listenany(port_hint)

        println(stdout, port)
        flush(stdout)

        while isopen(uv_server)
            sock = accept(uv_server)
            @async while isopen(sock)
                echo = Sockets.readavailable(sock)
                println(String(echo))
                write(
                    sock,
                    "HTTP/1.1 200 OK\r\n" *
                    "Server: TestServer\r\n" *
                    "Content-Type: text/html; charset=utf-8\r\n" *
                    "User-Agent: EasyCurl.jl\r\n" *
                    "\r\n" *
                    "<h1>Hello</h1>\n",
                )
                close(sock)
            end
        end
    end

    server_procs = open(`$(Base.julia_cmd()) -e $server_setup`, "w+")
    port_str = readline(server_procs)

    @test_throws "CurlError: Failed binding local connection end" http_get(
        "http://127.0.0.1:$(port_str)",
        interface = "10.10.10.10",
        read_timeout = 30,
        verbose = true,
    )

    response = http_get(
        "http://127.0.0.1:$(port_str)",
        headers = ["User-Agent" => "EasyCurl.jl"],
        interface = "0.0.0.0",
        read_timeout = 30,
        retry = 10,
        verbose = true,
    )

    @test http_status(response)               == 200
    @test http_body(response)                 == b"<h1>Hello</h1>\n"
    @test http_header(response, "User-Agent") == "EasyCurl.jl"
    @test http_header(response, "user-agent") == "EasyCurl.jl"

    kill(server_procs, Base.SIGKILL)
end
