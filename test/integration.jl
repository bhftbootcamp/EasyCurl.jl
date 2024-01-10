# test/integration

const headers = [
    "User-Agent" => "Curl.jl",
    "Content-Type" => "application/json"
]

const query = Dict{String,Any}(
    "echo" => "你好嗎"
)

const payload = Curl.urlencode_query_params(Dict{String,Any}(
    "echo" => "hello"
))

@testset "HTTP Requests" begin
    # Couldn't resolve host name

    @testset "Nonexistent host error" begin
        @test_throws "CurlError: Couldn't resolve host name" Curl.get(
            "https://bar-foo.foo/get",
            headers = headers,
            query = query,
            read_timeout = 30
        )
    end

    # GET request test
    @testset "GET request" begin
        response = Curl.get("httpbin.org/get", headers = headers, query = query, read_timeout = 30)
        @test response.status == 200

        body = JSON.parse(String(response.body))
        @test body["args"] == query
        @test body["url"]  == "http://httpbin.org/get?echo=你好嗎"
    end

    # HEAD request test
    @testset "HEAD request" begin
        response = Curl.head("httpbin.org/get", headers = headers, query = query, read_timeout = 30)
        @test response.status == 200
        @test isempty(response.body)
    end

    # POST request test
    @testset "POST request" begin
        response = Curl.post("httpbin.org/post", headers = headers, query = query, body = payload, read_timeout = 30)
        @test response.status == 200

        body = JSON.parse(String(response.body))
        @test body["data"] == payload
    end

    # PUT request test
    @testset "PUT request" begin
        response =
            Curl.put("httpbin.org/put", headers = headers, query = query, body = payload, read_timeout = 30)
        @test response.status == 200

        body = JSON.parse(String(response.body))
        @test body["data"] == payload
    end

    # PATCH request test
    @testset "PATCH request" begin
        response =
            Curl.patch("httpbin.org/patch", headers = headers, query = query, body = payload, read_timeout = 30)
        @test response.status == 200

        body = JSON.parse(String(response.body))
        @test body["data"] == payload
    end

    # DELETE request test
    @testset "DELETE request" begin
        response = Curl.delete("httpbin.org/delete", headers = headers, query = query, body = payload, read_timeout = 30)
        @test response.status == 200

        body = JSON.parse(String(response.body))
        @test body["data"] == payload
    end
end

@testset "Optional interface" begin
    server = Sockets.listen(Sockets.localhost, 1234)

    @async while isopen(server)
        sock = accept(server)
        @async while isopen(sock)
            echo = Sockets.readavailable(sock)
            println(String(echo))
            write(sock,
                  "HTTP/1.1 200 OK\r\n" *
                  "Server: TestServer\r\n" *
                  "Content-Type: text/html; charset=utf-8\r\n" *
                  "\r\n" *
                  "<h1>Hello</h1>\n")
            close(sock)
        end
    end

    sleep(2)

    @test_throws "CurlError: Failed binding local connection end" Curl.get(
        "http://127.0.0.1:1234",
        headers = ["User-Agent" => "Curl.jl"],
        interface = "10.10.10.10",
        read_timeout = 30
    )

    response = Curl.get(
        "http://127.0.0.1:1234",
        headers = ["User-Agent" => "Curl.jl"],
        interface = "0.0.0.0",
        read_timeout = 30,
        retries = 10,
    )

    @test response.status == 200
    @test String(response.body) == "<h1>Hello</h1>\n"

    close(server)
end
