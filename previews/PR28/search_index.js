var documenterSearchIndex = {"docs":
[{"location":"pages/protocols/imap/#IMAP","page":"IMAP","title":"IMAP","text":"","category":"section"},{"location":"pages/protocols/imap/#Types","page":"IMAP","title":"Types","text":"","category":"section"},{"location":"pages/protocols/imap/","page":"IMAP","title":"IMAP","text":"IMAPResponse\nIMAPOptions","category":"page"},{"location":"pages/protocols/imap/#EasyCurl.IMAPResponse","page":"IMAP","title":"EasyCurl.IMAPResponse","text":"IMAPResponse <: CurlResponse\n\nAn IMAP response object returned on a request completion.\n\nFields\n\nName Description Accessors (get)\nrequest_time::Float64 Total time spent receiving a response in seconds. imap_request_time(x)\nbody::Vector{UInt8} The response body as a vector of bytes. imap_body(x)\n\n\n\n\n\n","category":"type"},{"location":"pages/protocols/imap/#EasyCurl.IMAPOptions","page":"IMAP","title":"EasyCurl.IMAPOptions","text":"IMAPOptions <: CurlOptions\n\nRepresents options for configuring an IMAP request.\n\nFields\n\nName Description Default\nread_timeout::Real Timeout in seconds for reading the response. 30\nconnect_timeout::Real Maximum time in seconds that you allow the connection phase to take. 10\nssl_verifyhost::Bool Enables SSL certificate's host verification. true\nssl_verifypeer::Bool Enables the SSL certificate verification. true\nverbose::Bool Enables detailed output from Curl (useful for debugging). false\ninterface::Union{String,Nothing} Specifies a particular network interface to use for the request, or nothing to use the default. nothing\n\n\n\n\n\n","category":"type"},{"location":"pages/protocols/imap/#Methods","page":"IMAP","title":"Methods","text":"","category":"section"},{"location":"pages/protocols/imap/","page":"IMAP","title":"IMAP","text":"imap_request","category":"page"},{"location":"pages/protocols/imap/#EasyCurl.imap_request","page":"IMAP","title":"EasyCurl.imap_request","text":"imap_request(url::String, username::String, password::String; kw...) -> IMAPResponse\n\nSend a url IMAP request using username and password, then return a IMAPResponse object.\n\nKeyword arguments\n\nName Description Default\nmailbox::Union{Nothing,String} Required mailbox. nothing\ncommand Available IMAP commands after authentication. nothing\npath::Union{Nothing,String} The specific path or criteria of the query. nothing\nretry::Int64 Number of retries. 0\nretry_delay::Real Delay after failed request. 0.25\noptions... Another IMAP request options. \n\nExamples\n\njulia> response = imap_request(\n           \"imaps://imap.gmail.com:993\",\n           \"your_imap_username\",\n           \"your_imap_password\",\n           mailbox = \"INBOX\",\n           command = \"SEARCH SINCE 09-Sep-2024\",\n       );\n\njulia> imap_body(response) |> String |> print\n* SEARCH 1399 1400 1401 1402 1403 1404 1405 1406 1407 1408 1409 1410\n\n\n\n\n\n","category":"function"},{"location":"pages/constants/#HTTP-status-codes","page":"Constants","title":"HTTP status codes","text":"","category":"section"},{"location":"pages/constants/","page":"Constants","title":"Constants","text":"EasyCurl.HTTP_STATUS_CODES","category":"page"},{"location":"pages/constants/#EasyCurl.HTTP_STATUS_CODES","page":"Constants","title":"EasyCurl.HTTP_STATUS_CODES","text":"HTTP_STATUS_CODES::Dict{Int64,String}\n\nA dictionary that maps HTTP status codes to their corresponding messages:\n\n100 - \"CONTINUE\"\n101 - \"SWITCHING_PROTOCOLS\"\n102 - \"PROCESSING\"\n103 - \"EARLY_HINTS\"\n200 - \"OK\"\n201 - \"CREATED\"\n202 - \"ACCEPTED\"\n203 - \"NON_AUTHORITATIVE_INFORMATION\"\n204 - \"NO_CONTENT\"\n205 - \"RESET_CONTENT\"\n206 - \"PARTIAL_CONTENT\"\n207 - \"MULTI_STATUS\"\n208 - \"ALREADY_REPORTED\"\n226 - \"IM_USED\"\n300 - \"MULTIPLE_CHOICES\"\n301 - \"MOVED_PERMANENTLY\"\n302 - \"FOUND\"\n303 - \"SEE_OTHER\"\n304 - \"NOT_MODIFIED\"\n307 - \"TEMPORARY_REDIRECT\"\n308 - \"PERMANENT_REDIRECT\"\n400 - \"BAD_REQUEST\"\n401 - \"UNAUTHORIZED\"\n402 - \"PAYMENT_REQUIRED\"\n403 - \"FORBIDDEN\"\n404 - \"NOT_FOUND\"\n405 - \"METHOD_NOT_ALLOWED\"\n406 - \"NOT_ACCEPTABLE\"\n407 - \"PROXY_AUTHENTICATION_REQUIRED\"\n408 - \"REQUEST_TIMEOUT\"\n409 - \"CONFLICT\"\n410 - \"GONE\"\n411 - \"LENGTH_REQUIRED\"\n412 - \"PRECONDITION_FAILED\"\n413 - \"PAYLOAD_TOO_LARGE\"\n414 - \"URI_TOO_LONG\"\n415 - \"UNSUPPORTED_MEDIA_TYPE\"\n416 - \"RANGE_NOT_SATISFIABLE\"\n417 - \"EXPECTATION_FAILED\"\n418 - \"IM_A_TEAPOT\"\n421 - \"MISDIRECTED_REQUEST\"\n422 - \"UNPROCESSABLE_ENTITY\"\n423 - \"LOCKED\"\n424 - \"FAILED_DEPENDENCY\"\n425 - \"TOO_EARLY\"\n426 - \"UPGRADE_REQUIRED\"\n428 - \"PRECONDITION_REQUIRED\"\n429 - \"TOO_MANY_REQUESTS\"\n431 - \"REQUEST_HEADER_FIELDS_TOO_LARGE\"\n451 - \"UNAVAILABLE_FOR_LEGAL_REASONS\"\n500 - \"INTERNAL_SERVER_ERROR\"\n501 - \"NOT_IMPLEMENTED\"\n502 - \"BAD_GATEWAY\"\n503 - \"SERVICE_UNAVAILABLE\"\n504 - \"GATEWAY_TIMEOUT\"\n505 - \"HTTP_VERSION_NOT_SUPPORTED\"\n506 - \"VARIANT_ALSO_NEGOTIATES\"\n507 - \"INSUFFICIENT_STORAGE\"\n508 - \"LOOP_DETECTED\"\n510 - \"NOT_EXTENDED\"\n511 - \"NETWORK_AUTHENTICATION_REQUIRED\"\n\n\n\n\n\n","category":"constant"},{"location":"pages/curl/#Curl-Interface","page":"Curl Interface","title":"Curl Interface","text":"","category":"section"},{"location":"pages/curl/#Types","page":"Curl Interface","title":"Types","text":"","category":"section"},{"location":"pages/curl/","page":"Curl Interface","title":"Curl Interface","text":"CurlClient","category":"page"},{"location":"pages/curl/#EasyCurl.CurlClient","page":"Curl Interface","title":"EasyCurl.CurlClient","text":"CurlClient\n\nRepresents a client for making HTTP requests using libcurl. Allows for connection reuse.\n\nFields\n\ncurl_handle::Ptr{Cvoid}: The libcurl easy handle.\n\n\n\n\n\n","category":"type"},{"location":"pages/curl/#Methods","page":"Curl Interface","title":"Methods","text":"","category":"section"},{"location":"pages/curl/","page":"Curl Interface","title":"Curl Interface","text":"close\ncurl_open","category":"page"},{"location":"pages/curl/#Base.close","page":"Curl Interface","title":"Base.close","text":"close(client::CurlClient)\n\nCloses the client instance by cleaning up the associated libcurl easy handle.\n\n\n\n\n\n","category":"function"},{"location":"pages/curl/#EasyCurl.curl_open","page":"Curl Interface","title":"EasyCurl.curl_open","text":"curl_open(f::Function, x...; kw...)\n\nA helper function for executing a batch of curl requests, using the same client. Optionally configure the client (see CurlClient for more details).\n\nExamples\n\njulia> curl_open() do client\n           response = http_request(client, \"GET\", \"http://httpbin.org/get\")\n           curl_status(response)\n       end\n200\n\n\n\n\n\n","category":"function"},{"location":"pages/protocols/http/#HTTP","page":"HTTP","title":"HTTP","text":"","category":"section"},{"location":"pages/protocols/http/#Types","page":"HTTP","title":"Types","text":"","category":"section"},{"location":"pages/protocols/http/","page":"HTTP","title":"HTTP","text":"HTTPResponse\nHTTPOptions","category":"page"},{"location":"pages/protocols/http/#EasyCurl.HTTPResponse","page":"HTTP","title":"EasyCurl.HTTPResponse","text":"HTTPResponse <: CurlResponse\n\nAn HTTP response object returned on a request completion.\n\nFields\n\nName Description Accessors (get)\nstatus::Int The HTTP status code of the response. http_status(x)\nversion::Int The HTTP version received in the response. http_version(x)\nrequest_time::Float64 Total time spent receiving a response in seconds. http_request_time(x)\nbody::Vector{UInt8} The response body as a vector of bytes. http_body(x)\nheaders::Vector{Pair{String,String}} Headers received in the HTTP response. http_headers(x)\n\n\n\n\n\n","category":"type"},{"location":"pages/protocols/http/#EasyCurl.HTTPOptions","page":"HTTP","title":"EasyCurl.HTTPOptions","text":"HTTPOptions <: CurlOptions\n\nRepresents options for configuring an HTTP request.\n\nFields\n\nName Description Default\nlocation::Bool Allow HTTP redirects. true\nmax_redirs::Int Maximum number of redirects. 10\nconnect_timeout::Real Maximum time in seconds that you allow the connection phase to take. 10\nread_timeout::Real Timeout in seconds for reading the response. 30\nssl_verifyhost::Bool Enables SSL certificate's host verification. true\nssl_verifypeer::Bool Enables the SSL certificate verification. true\nverbose::Bool Enables detailed output from Curl (useful for debugging). false\nusername::Union{String,Nothing} Username for authentication. nothing\npassword::Union{String,Nothing} Password for authentication. nothing\nproxy::Union{String,Nothing} Proxy server URL, or nothing to bypass proxy settings. nothing\ninterface::Union{String,Nothing} Specifies a particular network interface to use for the request, or nothing to use the default. nothing\naccept_encoding::String Specifies the accepted encodings for the response, such as \"gzip\". \"gzip\"\nversion::Union{UInt,Nothing} Specifies the CURL version to use, or nothing to use the default version available. nothing\n\n\n\n\n\n","category":"type"},{"location":"pages/protocols/http/#Methods","page":"HTTP","title":"Methods","text":"","category":"section"},{"location":"pages/protocols/http/","page":"HTTP","title":"HTTP","text":"http_request\nhttp_get\nhttp_head\nhttp_post\nhttp_put\nhttp_patch\nhttp_delete","category":"page"},{"location":"pages/protocols/http/#EasyCurl.http_request","page":"HTTP","title":"EasyCurl.http_request","text":"http_request(method::String, url::String; kw...) -> HTTPResponse\n\nSend a url HTTP request using as method one of \"GET\", \"POST\", etc. and return a HTTPResponse object.\n\nKeyword arguments\n\nName Description Default\nquery Request query dictionary or string. nothing\nbody Request body. UInt8[]\nheaders::Vector{Pair{String,String}} Request headers. Pair{String,String}[]\nstatus_exception::Bool Whether to throw an exception if the response status code indicates an error. true\nretry::Int64 Number of retries. 0\nretry_delay::Real Delay after failed request. 0.25\noptions... Another HTTP request options. \n\nExamples\n\njulia> response = http_request(\n           \"POST\",\n           \"http://httpbin.org/post\",\n           headers = Pair{String,String}[\n               \"Content-Type\" => \"application/json\",\n               \"User-Agent\" => \"EasyCurl.jl\",\n           ],\n           query = \"qry=你好嗎\",\n           body = \"{\"data\":\"hi\"}\",\n           interface = \"en0\",\n           read_timeout = 5,\n           connect_timeout = 10,\n           retry = 10,\n       );\n\njulia> http_body(response) |> String |> print\n{\n  \"args\": {\n    \"qry\": \"你好嗎\"\n  }, \n  \"data\": \"{\"data\":\"hi\"}\", \n  \"files\": {}, \n  \"form\": {}, \n  \"headers\": {\n    \"Accept\": \"*/*\", \n    \"Accept-Encoding\": \"gzip\", \n    \"Content-Length\": \"13\", \n    \"Content-Type\": \"application/json\", \n    \"Host\": \"httpbin.org\", \n    \"User-Agent\": \"EasyCurl.jl\", \n    \"X-Amzn-Trace-Id\": \"Root=1-66e0d404-7597b1921ad026293b805690\"\n  }, \n  \"json\": {\n    \"data\": \"hi\"\n  }, \n  \"origin\": \"100.250.50.140\", \n  \"url\": \"http://httpbin.org/post?qry=你好嗎\"\n}\n\n\n\n\n\n","category":"function"},{"location":"pages/protocols/http/#EasyCurl.http_get","page":"HTTP","title":"EasyCurl.http_get","text":"http_get(url::AbstractString; kw...) -> HTTPResponse\n\nShortcut for http_request function, work similar to http_request(\"GET\", url; kw...).\n\nExamples\n\njulia> response = http_get(\n           \"http://httpbin.org/get\";\n           headers = Pair{String,String}[\n               \"Content-Type\" => \"application/json\",\n               \"User-Agent\" => \"EasyCurl.jl\",\n           ],\n           query = Dict(\"qry\" => \"你好嗎\"),\n       );\n\njulia> http_body(response) |> String |> print\n{\n  \"args\": {\n    \"qry\": \"你好嗎\"\n  }, \n  \"headers\": {\n    \"Accept\": \"*/*\", \n    \"Accept-Encoding\": \"gzip\", \n    \"Content-Type\": \"application/json\", \n    \"Host\": \"httpbin.org\", \n    \"User-Agent\": \"EasyCurl.jl\", \n    \"X-Amzn-Trace-Id\": \"Root=1-66e0e18f-0e26d7757885d0ec1966ef64\"\n  }, \n  \"origin\": \"100.250.50.140\", \n  \"url\": \"http://httpbin.org/get?qry=你好嗎\"\n}\n\n\n\n\n\n","category":"function"},{"location":"pages/protocols/http/#EasyCurl.http_head","page":"HTTP","title":"EasyCurl.http_head","text":"http_head(url::AbstractString; kw...) -> HTTPResponse\n\nShortcut for http_request function, work similar to http_request(\"HEAD\", url; kw...).\n\nExamples\n\njulia> response = http_head(\n           \"http://httpbin.org/get\";\n           headers = Pair{String,String}[\n               \"Content-Type\" => \"application/json\",\n               \"User-Agent\" => \"EasyCurl.jl\",\n           ],\n           query = \"qry=你好嗎\",\n           interface = \"0.0.0.0\",\n       );\n\njulia> http_body(response)\nUInt8[]\n\n\n\n\n\n","category":"function"},{"location":"pages/protocols/http/#EasyCurl.http_post","page":"HTTP","title":"EasyCurl.http_post","text":"http_post(url::AbstractString; kw...) -> HTTPResponse\n\nShortcut for http_request function, work similar to http_request(\"POST\", url; kw...).\n\nExamples\n\njulia> response = http_post(\n           \"http://httpbin.org/post\";\n           headers = Pair{String,String}[\n               \"Content-Type\" => \"application/json\",\n               \"User-Agent\" => \"EasyCurl.jl\",\n           ],\n           query = \"qry=你好嗎\",\n           body = \"{\"data\":\"hi\"}\",\n       );\n\njulia> http_body(response) |> String |> print\n{\n  \"args\": {\n    \"qry\": \"你好嗎\"\n  }, \n  \"data\": \"{\"data\":\"hi\"}\", \n  \"files\": {}, \n  \"form\": {}, \n  \"headers\": {\n    \"Accept\": \"*/*\", \n    \"Accept-Encoding\": \"gzip\", \n    \"Content-Length\": \"13\", \n    \"Content-Type\": \"application/json\", \n    \"Host\": \"httpbin.org\", \n    \"User-Agent\": \"EasyCurl.jl\", \n    \"X-Amzn-Trace-Id\": \"Root=1-66e0e208-4850928003a928fd230bfd59\"\n  }, \n  \"json\": {\n    \"data\": \"hi\"\n  }, \n  \"origin\": \"100.250.50.140\", \n  \"url\": \"http://httpbin.org/post?qry=你好嗎\"\n}\n\n\n\n\n\n","category":"function"},{"location":"pages/protocols/http/#EasyCurl.http_put","page":"HTTP","title":"EasyCurl.http_put","text":"http_put(url::AbstractString; kw...) -> HTTPResponse\n\nShortcut for http_request function, work similar to http_request(\"PUT\", url; kw...).\n\nExamples\n\njulia> response = http_put(\n           \"http://httpbin.org/put\";\n           headers = Pair{String,String}[\n               \"Content-Type\" => \"application/json\",\n               \"User-Agent\" => \"EasyCurl.jl\",\n           ],\n           query = \"qry=你好嗎\",\n           body = \"{\"data\":\"hi\"}\",\n       );\n\njulia> http_body(response) |> String |> print\n{\n  \"args\": {\n    \"qry\": \"你好嗎\"\n  }, \n  \"data\": \"{\"data\":\"hi\"}\", \n  \"files\": {}, \n  \"form\": {}, \n  \"headers\": {\n    \"Accept\": \"*/*\", \n    \"Accept-Encoding\": \"gzip\", \n    \"Content-Length\": \"13\", \n    \"Content-Type\": \"application/json\", \n    \"Host\": \"httpbin.org\", \n    \"User-Agent\": \"EasyCurl.jl\", \n    \"X-Amzn-Trace-Id\": \"Root=1-66e0e239-34f8cfdc41164300719ce1f1\"\n  }, \n  \"json\": {\n    \"data\": \"hi\"\n  }, \n  \"origin\": \"100.250.50.140\", \n  \"url\": \"http://httpbin.org/put?qry=你好嗎\"\n}\n\n\n\n\n\n","category":"function"},{"location":"pages/protocols/http/#EasyCurl.http_patch","page":"HTTP","title":"EasyCurl.http_patch","text":"http_patch(url::AbstractString; kw...) -> HTTPResponse\n\nShortcut for http_request function, work similar to http_request(\"PATCH\", url; kw...).\n\nExamples\n\njulia> response = http_patch(\n           \"http://httpbin.org/patch\";\n           headers = Pair{String,String}[\n               \"Content-Type\" => \"application/json\",\n               \"User-Agent\" => \"EasyCurl.jl\",\n           ],\n           query = \"qry=你好嗎\",\n           body = \"{\"data\":\"hi\"}\",\n       );\n\njulia> http_body(response) |> String |> print\n{\n  \"args\": {\n    \"qry\": \"你好嗎\"\n  }, \n  \"data\": \"{\"data\":\"hi\"}\", \n  \"files\": {}, \n  \"form\": {}, \n  \"headers\": {\n    \"Accept\": \"*/*\", \n    \"Accept-Encoding\": \"gzip\", \n    \"Content-Length\": \"13\", \n    \"Content-Type\": \"application/json\", \n    \"Host\": \"httpbin.org\", \n    \"User-Agent\": \"EasyCurl.jl\", \n    \"X-Amzn-Trace-Id\": \"Root=1-66e0e266-5bd4762c619fbd642710bf3d\"\n  }, \n  \"json\": {\n    \"data\": \"hi\"\n  }, \n  \"origin\": \"100.250.50.140\", \n  \"url\": \"http://httpbin.org/patch?qry=你好嗎\"\n}\n\n\n\n\n\n","category":"function"},{"location":"pages/protocols/http/#EasyCurl.http_delete","page":"HTTP","title":"EasyCurl.http_delete","text":"http_delete(url::AbstractString; kw...) -> HTTPResponse\n\nShortcut for http_request function, work similar to http_request(\"DELETE\", url; kw...).\n\nExamples\n\njulia> response = http_delete(\n           \"http://httpbin.org/delete\";\n           headers = Pair{String,String}[\n               \"Content-Type\" => \"application/json\",\n               \"User-Agent\" => \"EasyCurl.jl\",\n           ],\n           query = \"qry=你好嗎\",\n           body = \"{\"data\":\"hi\"}\",\n       );\n\njulia> http_body(response) |> String |> print\n{\n  \"args\": {\n    \"qry\": \"你好嗎\"\n  }, \n  \"data\": \"{\"data\":\"hi\"}\", \n  \"files\": {}, \n  \"form\": {}, \n  \"headers\": {\n    \"Accept\": \"*/*\", \n    \"Accept-Encoding\": \"gzip\", \n    \"Content-Length\": \"13\", \n    \"Content-Type\": \"application/json\", \n    \"Host\": \"httpbin.org\", \n    \"User-Agent\": \"EasyCurl.jl\", \n    \"X-Amzn-Trace-Id\": \"Root=1-66e0e292-34acbab950035ea1763c3aca\"\n  }, \n  \"json\": {\n    \"data\": \"hi\"\n  }, \n  \"origin\": \"100.250.50.140\", \n  \"url\": \"http://httpbin.org/delete?qry=你好嗎\"\n}\n\n\n\n\n\n","category":"function"},{"location":"pages/protocols/http/#Utilities","page":"HTTP","title":"Utilities","text":"","category":"section"},{"location":"pages/protocols/http/","page":"HTTP","title":"HTTP","text":"http_iserror\nhttp_headers\nhttp_header\nEasyCurl.HTTP_VERSION_MAP","category":"page"},{"location":"pages/protocols/http/#EasyCurl.http_iserror","page":"HTTP","title":"EasyCurl.http_iserror","text":"http_iserror(x::HTTPResponse) -> Bool\n\nDetermines if the HTTP response indicates an error (status codes 400 and above).\n\nExamples\n\njulia> response = http_request(\"GET\", \"http://httpbin.org/get\");\n\njulia> http_iserror(response)\nfalse\n\n\n\n\n\n","category":"function"},{"location":"pages/protocols/http/#EasyCurl.http_headers","page":"HTTP","title":"EasyCurl.http_headers","text":"http_headers(x::HTTPResponse, key::String) -> Vector{String}\n\nRetrieve all values for a specific header field from a HTTPResponse object. This function is case-insensitive with regard to the header field name.\n\nExamples\n\njulia> response = http_request(\"GET\", \"http://httpbin.org/get\");\n\njulia> http_headers(response, \"Content-Type\")\n1-element Vector{String}:\n \"application/json\"\n\njulia> http_headers(response, \"nonexistent-header\")\nString[]\n\n\n\n\n\n","category":"function"},{"location":"pages/protocols/http/#EasyCurl.http_header","page":"HTTP","title":"EasyCurl.http_header","text":"http_header(x::HTTPResponse, key::String, default = nothing)\n\nRetrieve the first value of a specific header field by key from a HTTPResponse object. If the header is not found, the function returns a default value. This function is case-insensitive with regard to the header field name.\n\nExamples\n\njulia> response = http_request(\"GET\", \"http://httpbin.org/get\")\n\njulia> http_header(response, \"Content-Type\")\n\"application/json\"\n\njulia> http_header(response, \"nonexistent-header\", \"default-value\")\n\"default-value\"\n\n\n\n\n\n","category":"function"},{"location":"pages/protocols/http/#EasyCurl.HTTP_VERSION_MAP","page":"HTTP","title":"EasyCurl.HTTP_VERSION_MAP","text":"HTTP_VERSION_MAP::Dict{UInt64,String}\n\nMaps CURL numerical constants for HTTP versions to their string representations.\n\n0x00000001 (CURL_HTTP_VERSION_1_0) - \"1.0\": HTTP 1.0\n0x00000002 (CURL_HTTP_VERSION_1_1) - \"1.1\": HTTP 1.1\n0x00000003 (CURL_HTTP_VERSION_2_0) - \"2.0\": HTTP 2.0\n\n\n\n\n\n","category":"constant"},{"location":"pages/error_handling/#Error-handling","page":"Error handling","title":"Error handling","text":"","category":"section"},{"location":"pages/error_handling/","page":"Error handling","title":"Error handling","text":"If the problem occurs on the EasyCurl side then CurlError exception will be thrown.","category":"page"},{"location":"pages/error_handling/","page":"Error handling","title":"Error handling","text":"CurlError","category":"page"},{"location":"pages/error_handling/#EasyCurl.CurlError","page":"Error handling","title":"EasyCurl.CurlError","text":"CurlError <: Exception\n\nType wrapping LibCURL error codes. Returned when a libcurl error occurs.\n\nFields\n\ncode::UInt64: The LibCURL error code (see libcurl error codes).\nmessage::String: The error message.\n\nExamples\n\njulia> http_request(\"GET\", \"http://httpbin.org/status/400\", interface = \"9.9.9.9\")\nERROR: CurlError: Failed binding local connection end\n[...]\n\njulia> http_request(\"GET\", \"http://httpbin.org/status/400\", interface = \"\")\nERROR: CurlError: Couldn't connect to server\n[...]\n\n\n\n\n\n","category":"type"},{"location":"pages/error_handling/","page":"Error handling","title":"Error handling","text":"Or, if the problem was caused by HHTP, a HTTPStatusError exception will be thrown.","category":"page"},{"location":"pages/error_handling/","page":"Error handling","title":"Error handling","text":"HTTPStatusError","category":"page"},{"location":"pages/error_handling/#EasyCurl.HTTPStatusError","page":"Error handling","title":"EasyCurl.HTTPStatusError","text":"HTTPStatusError <: Exception\n\nType wrapping HTTP error codes. Returned from http_request when an HTTP error occurs.\n\nFields\n\ncode::Int64: The HTTP error code (see HTTP_STATUS_CODES).\nmessage::String: The error message.\nresponse::HTTPResponse: The HTTP response object.\n\nExamples\n\njulia> http_request(\"GET\", \"http://httpbin.org/status/400\")\nERROR: HTTPStatusError: BAD_REQUEST\n[...]\n\njulia> http_request(\"GET\", \"http://httpbin.org/status/404\")\nERROR: HTTPStatusError: NOT_FOUND\n[...]\n\n\n\n\n\n","category":"type"},{"location":"pages/error_handling/","page":"Error handling","title":"Error handling","text":"Below is a small example of error handling.","category":"page"},{"location":"pages/error_handling/#Example","page":"Error handling","title":"Example","text":"","category":"section"},{"location":"pages/error_handling/","page":"Error handling","title":"Error handling","text":"using EasyCurl\n\ntry\n    http_request(\"GET\", \"http://httpbin.org/status/400\", read_timeout = 30)\n    # If the request is successful, you can process the response here\n    # ...\ncatch e\n    if isa(e, CurlError)\n        if e.code == EasyCurl.CURLE_COULDNT_CONNECT\n            # Handle the case where the connection to the server could not be made\n        elseif e.code == EasyCurl.CURLE_OPERATION_TIMEDOUT\n            # Handle the case where the operation timed out\n        end\n    elseif isa(e, HTTPStatusError)\n        if e.code == 400\n            # Handle a 400 Bad Request error specifically\n        end\n    end\n    rethrow(e)\nend","category":"page"},{"location":"#EasyCurl.jl","page":"Home","title":"EasyCurl.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"EasyCurl is a lightweight Julia package that provides a user-friendly wrapper for the libcurl C library, for making requests.","category":"page"},{"location":"","page":"Home","title":"Home","text":"<html lang=\"en\">\n  <body>\n      <table>\n          <tr>\n              <th>Protocols:</th>\n              <th><div align=\"center\">HTTP/HTTPS</div></th>\n              <th><div align=\"center\">IMAP/IMAPS</div></th>\n          </tr>\n          <tr>\n              <th></th>\n              <th><div align=\"center\">✓</div></th>\n              <th><div align=\"center\">✓</div></th>\n          </tr>\n      </table>\n  </body>\n</html>","category":"page"},{"location":"#Installation","page":"Home","title":"Installation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"To install EasyCurl, simply use the Julia package manager:","category":"page"},{"location":"","page":"Home","title":"Home","text":"] add EasyCurl","category":"page"},{"location":"#Usage","page":"Home","title":"Usage","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Here is an example usage of EasyCurl:","category":"page"},{"location":"","page":"Home","title":"Home","text":"In the example, a POST request is sent to http://httpbin.org/post using the en0 network interface","category":"page"},{"location":"","page":"Home","title":"Home","text":"using EasyCurl\n\n# 'interface' argument specifies the network interface to use for the request\n# 'read_timeout' and 'connect_timeout' define how long to wait for a response or connection\n# 'retry' argument specifies how many times to retry the request if it fails initially\n\nresponse = http_request(\n    \"POST\",\n    \"http://httpbin.org/post\",\n    headers = Pair{String,String}[\n        \"Content-Type\" => \"application/json\",\n        \"User-Agent\" => \"EasyCurl.jl\",\n    ],\n    query = \"qry=你好嗎\",\n    body = \"{\\\"data\\\":\\\"hi\\\"}\",\n    interface = \"en0\",\n    read_timeout = 5,\n    connect_timeout = 10,\n    retry = 10,\n)\n\njulia> http_body(response) |> String |> print\n{\n  \"args\": {\n    \"qry\": \"\\u4f60\\u597d\\u55ce\"\n  }, \n  \"data\": \"{\\\"data\\\":\\\"hi\\\"}\", \n  \"files\": {}, \n  \"form\": {}, \n  \"headers\": {\n    \"Accept\": \"*/*\", \n    \"Accept-Encoding\": \"gzip\", \n    \"Content-Length\": \"13\", \n    \"Content-Type\": \"application/json\", \n    \"Host\": \"httpbin.org\", \n    \"User-Agent\": \"EasyCurl.jl\", \n    \"X-Amzn-Trace-Id\": \"Root=1-66e0dce3-7dbea4a9357524fb19628e26\"\n  }, \n  \"json\": {\n    \"data\": \"hi\"\n  }, \n  \"origin\": \"100.250.50.140\", \n  \"url\": \"http://httpbin.org/post?qry=\\u4f60\\u597d\\u55ce\"\n}","category":"page"},{"location":"","page":"Home","title":"Home","text":"This example shows how to use CurlClient for making HTTP requests by reusing the same client instance, which can help in speeding up the requests when making multiple calls to the same server:","category":"page"},{"location":"","page":"Home","title":"Home","text":"using EasyCurl\n\ncurl_client = CurlClient()\n\n# Perform a GET request\nresponse = http_request(\n    curl_client,\n    \"GET\",\n    \"http://httpbin.org/get\",\n    headers = Pair{String,String}[\n        \"Content-Type\" => \"application/json\",\n        \"User-Agent\" => \"EasyCurl.jl\",\n    ],\n)\n\njulia> http_body(response) |> String |> print\n{\n  \"args\": {}, \n  \"headers\": {\n    \"Accept\": \"*/*\", \n    \"Accept-Encoding\": \"gzip\", \n    \"Content-Type\": \"application/json\", \n    \"Host\": \"httpbin.org\", \n    \"User-Agent\": \"EasyCurl.jl\", \n    \"X-Amzn-Trace-Id\": \"Root=1-66e0de99-735b60c138a5445c7f7b5c7e\"\n  }, \n  \"origin\": \"100.250.50.140\", \n  \"url\": \"http://httpbin.org/get\"\n}\n\nclose(curl_client)","category":"page"},{"location":"","page":"Home","title":"Home","text":"In addition to HTTP, you can also make IMAP requests to retrieve email from a server:","category":"page"},{"location":"","page":"Home","title":"Home","text":"using EasyCurl\n\nresponse = imap_request(\n    \"imaps://imap.gmail.com:993/INBOX\",\n    \"username@example.com\",\n    \"password\",\n    command = \"SEARCH SINCE 09-Sep-2024\",\n)\n\njulia> imap_body(response) |> String |> print\n* SEARCH 610 611 612 613 614 615 616 617 618 619 620 621 622 623 624 625 626 627 628 629","category":"page"},{"location":"#Using-a-proxy-with-EasyCurl","page":"Home","title":"Using a proxy with EasyCurl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"To use a proxy for all your HTTP and HTTPS requests in EasyCurl, you can set the following environment variables:","category":"page"},{"location":"","page":"Home","title":"Home","text":"all_proxy: Proxy for all protocols\nhttp_proxy: Proxy for HTTP requests\nhttps_proxy: Proxy for HTTPS requests\nno_proxy: Domains to exclude from proxying","category":"page"},{"location":"","page":"Home","title":"Home","text":"# 'your_proxy_username' your proxy account's username\n# 'your_proxy_password' your proxy account's password\n# 'your_proxy_host' the hostname or IP address of your proxy server\n# 'your_proxy_port' the port number your proxy server listens on\n\n# socks5 proxy for all protocols\nENV[\"all_proxy\"] = \"socks5://your_proxy_username:your_proxy_password@your_proxy_host:your_proxy_port\"\n\n# domains that should bypass the proxy\nENV[\"no_proxy\"] = \"localhost,.local,.mywork\"","category":"page"},{"location":"","page":"Home","title":"Home","text":"When executing the http_request function with the proxy parameter, it will ignore the environment variable settings for proxies","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> http_request(\"GET\", \"http://httpbin.org/get\",\n    proxy = \"socks5://your_proxy_username:your_proxy_password@your_proxy_host:your_proxy_port\")","category":"page"}]
}
