#__ integration

const HTTPBIN_URL = get(ENV, "HTTPBIN_URL", "http://httpbin.org")

const query = Dict{String,Any}(
    "echo" => "你好嗎"
)

@testset "HTTP Requests" begin
    # Test for nonexistent host error
    @testset "Nonexistent host error" begin
        @test_throws CurlEasyError{6} http_get(
            "https://bar-foo.foo/get",
            read_timeout = 30,
            verbose = true,
        )
    end

    # Test for GET request
    @testset "GET request" begin
        response = http_get(joinpath(HTTPBIN_URL, "get"), query = query, read_timeout = 30)
        @test http_status(response) == 200
        body = parse_json(http_body(response))
        @test body["args"] == query
        @test body["url"] == joinpath(HTTPBIN_URL, "get") * "?echo=你好嗎"
    end

    # Test for HEAD request
    @testset "HEAD request" begin
        response = http_head(
            joinpath(HTTPBIN_URL, "get"),
            headers = headers = [
                "Content-Type" => "application/json"
            ],
            read_timeout = 30,
            verbose = true,
        )
        @test http_status(response) == 200
        @test isempty(http_body(response))
    end

    # Test for POST request
    @testset "POST request" begin
        response = http_post(
            joinpath(HTTPBIN_URL, "post"),
            headers = headers = [
                "Content-Type" => "application/json"
            ],
            body = "echo=hello",
            read_timeout = 30,
            verbose = true,
        )
        @test http_status(response) == 200
        body = parse_json(http_body(response))
        @test body["data"] == "echo=hello"
    end

    # Test for PUT request
    @testset "PUT request" begin
        response = http_put(
            joinpath(HTTPBIN_URL, "put"),
            headers = headers = [
                "Content-Type" => "application/json"
            ],
            body = "echo=hello",
            read_timeout = 30,
            verbose = true,
        )
        @test http_status(response) == 200
        body = parse_json(http_body(response))
        @test body["data"] == "echo=hello"
    end

    # Test for PATCH request
    @testset "PATCH request" begin
        response = http_patch(
            joinpath(HTTPBIN_URL, "patch"),
            headers = headers = [
                "Content-Type" => "application/json"
            ],
            query = query,
            body = "echo=hello",
            read_timeout = 30,
            verbose = true,
        )
        @test http_status(response) == 200
        body = parse_json(http_body(response))
        @test body["data"] == "echo=hello"
    end

    # Test for DELETE request
    @testset "DELETE request" begin
        response = http_delete(
            joinpath(HTTPBIN_URL, "delete"),
            headers = headers = [
                "Content-Type" => "application/json"
            ],
            read_timeout = 30,
            verbose = true,
        )
        @test http_status(response) == 200
    end

    @testset "HTTP status error" begin
        @test_throws HTTPStatusError{400} http_get(
            joinpath(HTTPBIN_URL, "status/400"),
            read_timeout = 30,
            verbose = true,
        )
    end
end

@testset "Optional interface" begin
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

    @test_throws CurlEasyError{45} http_get(
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
    @test isnothing(http_header(response, "invalid-key"))
    @test http_version(response) == CURL_HTTP_VERSION_1_1
    @test http_total_time(response) > 0
    @test http_headers(response) == [
        "server" => "TestServer", 
        "content-type" => "text/html; charset=utf-8", 
        "user-agent" => "EasyCurl.jl"
    ]
    @test http_headers(response, "User-Agent") == ["EasyCurl.jl"]
    @test curl_body(response) == b"<h1>Hello</h1>\n"
    @test curl_total_time(response) > 0

    kill(server_procs, Base.SIGKILL)
end

@testset "Stream" begin
    chunks = Vector{UInt8}[]
    response = http_open("GET", joinpath(HTTPBIN_URL, "stream/3"), query = query) do stream
        while !eof(stream)
            push!(chunks, read(stream, 280))
        end
    end
    @test http_status(response) == 200
    for chunk in chunks
        body = parse_json(chunk)
        @test body["args"] == query
        @test body["url"] == joinpath(HTTPBIN_URL, "stream/3?echo=你好嗎")
    end

    body = UInt8[]
    response = http_open("GET", joinpath(HTTPBIN_URL, "get"), query = query) do stream
        append!(body, read(stream))
    end
    body_dict = parse_json(body)
    @test body_dict["args"] == query
    @test body_dict["url"] == joinpath(HTTPBIN_URL, "get?echo=你好嗎")
end

@testset "Client reusing" begin
    client = CurlClient()
    @test isopen(client)

    response = http_request(client, "GET", joinpath(HTTPBIN_URL, "get"), query = query)
    @test http_status(response) == 200
    body = parse_json(http_body(response))
    @test body["args"] == query
    @test body["url"] == joinpath(HTTPBIN_URL, "get")*"?echo=你好嗎"

    response = http_request(client, "POST", joinpath(HTTPBIN_URL, "post"), query = query)
    @test http_status(response) == 200
    body = parse_json(http_body(response))
    @test body["args"] == query
    @test body["url"] == joinpath(HTTPBIN_URL, "post")*"?echo=你好嗎"

    close(client)
    @test !isopen(client)
end
