## Error handling

If the problem occurs on the EasyCurl side then [`CurlError`](@ref) exception will be thrown.

```@docs
CurlError
```

Or, if the problem was caused by HHTP, a [`CurlStatusError`](@ref) exception will be thrown.

```@docs
CurlStatusError
```

Below is a small example of error handling.

### Example

```julia
using EasyCurl

headers = Pair{String,String}[
    "User-Agent" => "EasyCurl.jl",
    "Content-Type" => "application/json",
]

try
    response = curl_request("GET", "http://httpbin.org/status/400", query = "echo=你好嗎",
        headers = headers, interface = "0.0.0.0", read_timeout = 30, retry = 1)
    # If the request is successful, you can process the response here
    # ...
catch e
    if isa(e, CurlError{EasyCurl.CURLE_COULDNT_CONNECT})
        # Handle the case where the connection to the server could not be made
    elseif isa(e, CurlError{EasyCurl.CURLE_OPERATION_TIMEDOUT})
        # Handle the case where the operation timed out
    elseif isa(e, CurlStatusError{400})
        # Handle a 400 Bad Request error specifically
        rethrow(e)
    end
end
```
