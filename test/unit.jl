#__ unit

@testset verbose = true "URL Encoding" begin

    @testset "URL Query Parameter Encoding" begin
        idle = CurlClient()
        try
            @test EasyCurl.to_query(idle, Dict{String,Any}()) == ""
            @test EasyCurl.to_query(idle, Dict{String,Any}("a" => "b")) == "a=b"

            encoded_params = EasyCurl.to_query(idle, Dict{String,Any}("a" => "1", "b" => "2", "c" => "c"))
            @test contains(encoded_params, "a=1")
            @test contains(encoded_params, "b=2")
            @test contains(encoded_params, "c=c")

            encoded_params = EasyCurl.to_query(idle, Dict{String,Any}("a" => 1, "b" => 1.0, "c" => 'c'))
            @test contains(encoded_params, "a=1")
            @test contains(encoded_params, "b=1.0")
            @test contains(encoded_params, "c=c")

            encoded_params = EasyCurl.to_query(idle, Dict{String,Any}("a" => "b", "a" => nothing, "c" => missing))
            @test contains(encoded_params, "c=missing")
            @test contains(encoded_params, "a=nothing")

            @test EasyCurl.to_query(idle, "a=1") == "a=1"
            @test EasyCurl.to_query(idle, Dict{String,Any}("a" => "")) == "a"
        finally
            close(idle)
        end
    end

    @testset "URL Component Encoding" begin
        idle = CurlClient()
        try
            @test EasyCurl.urlencode(idle, "") == ""
            @test EasyCurl.urlencode(idle, "aaa") == "aaa"
            @test EasyCurl.urlencode(idle, "http://blabla.mge:9000?c=c&b=1.0&a=1") == "http%3A%2F%2Fblabla.mge%3A9000%3Fc%3Dc%26b%3D1.0%26a%3D1"
            @test EasyCurl.urlencode(idle, "http://blabla.mge:9000?") == "http%3A%2F%2Fblabla.mge%3A9000%3F"
            @test EasyCurl.urlencode(idle, SubString("http://blabla.mge:9000?c=c&b=1.0&a=1", 2)) == "ttp%3A%2F%2Fblabla.mge%3A9000%3Fc%3Dc%26b%3D1.0%26a%3D1"
        finally
            close(idle)
        end
    end

    @testset "URL Component Decoding" begin
        idle = CurlClient()
        try
            @test EasyCurl.urldecode(idle, "") == ""
            @test EasyCurl.urldecode(idle, "aaa") == "aaa"
            @test EasyCurl.urldecode(idle, "http%3A%2F%2Fblabla.mge%3A9000%3Fc%3Dc%26b%3D1.0%26a%3D1") == "http://blabla.mge:9000?c=c&b=1.0&a=1"
            @test EasyCurl.urldecode(idle, "http%3A%2F%2Fblabla.mge%3A9000%3F") == "http://blabla.mge:9000?"
            @test EasyCurl.urldecode(idle, SubString("http%3A%2F%2Fblabla.mge%3A9000%3Fc%3Dc%26b%3D1.0%26a%3D1", 2)) == "ttp://blabla.mge:9000?c=c&b=1.0&a=1"
        finally
            close(idle)
        end
    end

    @testset "Encode/Decode Random Strings Test" begin
        idle = CurlClient()
        try
            chars = map(Char, 32:126) # Printable ASCII characters
            for _ = 1:1000
                random_str = String(rand(chars, 30))
                encoded_str = EasyCurl.urlencode(idle, random_str)
                decoded_str = EasyCurl.urldecode(idle, encoded_str)
                @test random_str == decoded_str
            end
        finally
            close(idle)
        end
    end

    @testset "curl_joinurl Function Tests" begin
        @test curl_joinurl("http://example.com") == "http://example.com"
        @test curl_joinurl("http://example.com", "path") == "http://example.com/path"
        @test curl_joinurl("http://example.com", "path", "to", "resource") == "http://example.com/path/to/resource"
        @test curl_joinurl("http://example.com/", "path") == "http://example.com/path"
        @test curl_joinurl("http://example.com", "/path") == "http://example.com/path"
        @test curl_joinurl("http://example.com/", "/path/", "/to/", "/resource/") == "http://example.com/path/to/resource"
        @test curl_joinurl("http://example.com", "path to", "the resource") == "http://example.com/path to/the resource"
        @test curl_joinurl("http://example.com", "", "path") == "http://example.com/path"
        @test curl_joinurl("http://example.com", "path", "") == "http://example.com/path"
        @test curl_joinurl("http://example.com", "path?", "key=value") == "http://example.com/path?/key=value"
        @test curl_joinurl("http://example.com", "path?", "key=value", "more=info") == "http://example.com/path?/key=value/more=info"
    end
end

@testset "build_imap_url Function Tests" begin
    @test EasyCurl.build_imap_url("imap://example.com", nothing, nothing) ==
          "imap://example.com"

    @test EasyCurl.build_imap_url("imap://example.com", "INBOX", nothing) ==
          "imap://example.com/INBOX"

    @test EasyCurl.build_imap_url("imap://example.com", nothing, "UIDVALIDITY=1234") ==
          "imap://example.com;UIDVALIDITY=1234"

    @test EasyCurl.build_imap_url("imap://example.com", "INBOX", "UIDVALIDITY=1234") ==
          "imap://example.com/INBOX;UIDVALIDITY=1234"
end
