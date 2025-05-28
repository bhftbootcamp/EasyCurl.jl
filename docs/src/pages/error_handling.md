# Error handling

If the problem occurs on the EasyCurl side then [`AbstractCurlError`](@ref) exception will be thrown.

```@docs
AbstractCurlError
CurlEasyError
CurlMultiError
```

Or, if the problem was caused by HHTP, a [`HTTPStatusError`](@ref) exception will be thrown.

```@docs
HTTPStatusError
```

Below are some small examples of error handling.

## Example

Classic way of error handling:

```julia
using EasyCurl

try
    http_request("GET", "http://httpbin.org/status/400"; read_timeout = 30)
    # If the request is successful, you can process the response here
    # ...
catch e
    if isa(e, CurlEasyError)
        if e.code == EasyCurl.CURLE_COULDNT_CONNECT
            # Handle the case where the connection to the server could not be made
        elseif e.code == EasyCurl.CURLE_OPERATION_TIMEDOUT
            # Handle the case where the operation timed out
        end
    elseif isa(e, HTTPStatusError)
        if e.code == 400
            # Handle a 400 Bad Request error specifically
        end
    end
    rethrow(e)
end
```

Handling errors using error codes as a type parameter:

```julia
using EasyCurl

try
    http_request("GET", "http://httpbin.org/status/400"; read_timeout = 30)
    # If the request is successful, you can process the response here
    # ...
catch e
    if isa(e, CurlEasyError{EasyCurl.CURLE_COULDNT_CONNECT})
        # Handle the case where the connection to the server could not be made
    elseif isa(e, CurlEasyError{EasyCurl.CURLE_OPERATION_TIMEDOUT})
        # Handle the case where the operation timed out
    elseif isa(e, HTTPStatusError{400})
        # Handle a 400 Bad Request error specifically
    end
    rethrow(e)
end
```
