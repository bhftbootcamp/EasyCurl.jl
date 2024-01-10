# test/unit

@testset "URL Encoding" begin
    @testset "URL Query Parameter Encoding" begin
        @test Curl.urlencode_query_params(Dict{String,Any}()) == ""
        @test Curl.urlencode_query_params(Dict{String,Any}("a" => "b")) == "a=b"

        encoded_params = Curl.urlencode_query_params(Dict{String,Any}("a" => "1", "b" => "2", "c" => "c"))
        @test contains(encoded_params, "a=1")
        @test contains(encoded_params, "b=2")
        @test contains(encoded_params, "c=c")

        encoded_params = Curl.urlencode_query_params(Dict{String,Any}("a" => 1, "b" => 1.0, "c" => 'c'))
        @test contains(encoded_params, "a=1")
        @test contains(encoded_params, "b=1.0")
        @test contains(encoded_params, "c=c")

        encoded_params = Curl.urlencode_query_params(Dict{String,Any}("a" => "b", "a" => nothing, "c" => missing))
        @test contains(encoded_params, "c=missing")
        @test contains(encoded_params, "a=nothing")
    end

    @testset "URL Component Encoding" begin
        @test Curl.urlencode("") == ""
        @test Curl.urlencode("aaa") == "aaa"
        @test Curl.urlencode("http://blabla.mge:9000?c=c&b=1.0&a=1") == "http%3A%2F%2Fblabla.mge%3A9000%3Fc%3Dc%26b%3D1.0%26a%3D1"
        @test Curl.urlencode("http://blabla.mge:9000?") == "http%3A%2F%2Fblabla.mge%3A9000%3F"
        @test Curl.urlencode(SubString("http://blabla.mge:9000?c=c&b=1.0&a=1", 2)) == "ttp%3A%2F%2Fblabla.mge%3A9000%3Fc%3Dc%26b%3D1.0%26a%3D1"
    end

    @testset "URL Component Decoding" begin
        @test Curl.urldecode("") == ""
        @test Curl.urldecode("aaa") == "aaa"
        @test Curl.urldecode("http%3A%2F%2Fblabla.mge%3A9000%3Fc%3Dc%26b%3D1.0%26a%3D1") == "http://blabla.mge:9000?c=c&b=1.0&a=1"
        @test Curl.urldecode("http%3A%2F%2Fblabla.mge%3A9000%3F") == "http://blabla.mge:9000?"
        @test Curl.urldecode(SubString("http%3A%2F%2Fblabla.mge%3A9000%3Fc%3Dc%26b%3D1.0%26a%3D1", 2)) == "ttp://blabla.mge:9000?c=c&b=1.0&a=1"
    end

    @testset "Encode/Decode Random Strings Test" begin
        chars = map(Char, 32:126) # Printable ASCII characters
        for _ = 1:1000
            random_str = String(rand(chars, 30))
            encoded_str = Curl.urlencode(random_str)
            decoded_str = Curl.urldecode(encoded_str)
            @test random_str == decoded_str
        end
    end

    @testset "joinurl Function Tests" begin
        @test Curl.joinurl("http://example.com") == "http://example.com"
        @test Curl.joinurl("http://example.com", "path") == "http://example.com/path"
        @test Curl.joinurl("http://example.com", "path", "to", "resource") == "http://example.com/path/to/resource"
        @test Curl.joinurl("http://example.com/", "path") == "http://example.com/path"
        @test Curl.joinurl("http://example.com", "/path") == "http://example.com/path"
        @test Curl.joinurl("http://example.com/", "/path/", "/to/", "/resource/") == "http://example.com/path/to/resource"
        @test Curl.joinurl("http://example.com", "path to", "the resource") == "http://example.com/path to/the resource"
        @test Curl.joinurl("http://example.com", "", "path") == "http://example.com/path"
        @test Curl.joinurl("http://example.com", "path", "") == "http://example.com/path"
        @test Curl.joinurl("http://example.com", "path?", "key=value") == "http://example.com/path?/key=value"
        @test Curl.joinurl("http://example.com", "path?", "key=value", "more=info") == "http://example.com/path?/key=value/more=info"
    end
end
