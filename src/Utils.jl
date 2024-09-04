#__ Utils

"""
    EasyCurl.urlencode(s::AbstractString)

Encode a string `s` into URI using only the US-ASCII characters legal within a URI.

## Examples

```julia-repl
julia> EasyCurl.urlencode("[curl]")
"%5Bcurl%5D"
```
"""
function urlencode(s::AbstractString)
    curl = curl_easy_init()
    try
        urlencode(curl, s)
    finally
        curl_easy_cleanup(curl)
    end
end

function urlencode(curl, s::AbstractString)
    b_arr = curl_easy_escape(curl, s, sizeof(s))
    esc_s = unsafe_string(b_arr)
    curl_free(b_arr)
    return esc_s
end

function urlencode_query_params(params::AbstractDict{String,T}) where {T<:Any}
    curl = curl_easy_init()
    try
        urlencode_query_params(curl, params)
    finally
        curl_easy_cleanup(curl)
    end
end

function urlencode_query_params(curl, params::AbstractDict{String,T}) where {T<:Any}
    str = ""
    for (k, v) in params
        if v !== ""
            ep = urlencode(curl, string(k)) * "=" * urlencode(curl, string(v))
        else
            ep = urlencode(curl, string(k))
        end
        if str == ""
            str = ep
        else
            str *= "&" * ep
        end
    end
    return str
end

"""
    EasyCurl.urldecode(s::AbstractString)

Decode an encoded URI string `s` back to normal string.

## Examples

```julia-repl
julia> EasyCurl.urldecode("%5Bcurl%5D")
"[curl]"
```
"""
function urldecode(s::AbstractString)
    curl = curl_easy_init()
    try
        urldecode(curl, s)
    finally
        curl_easy_cleanup(curl)
    end
end

function urldecode(curl, s::AbstractString)
    b_arr = curl_easy_unescape(curl, s, 0, C_NULL)
    unesc_s = unsafe_string(b_arr)
    curl_free(b_arr)
    return unesc_s
end

"""
    EasyCurl.joinurl(basepart::AbstractString, parts::AbstractString...)::String

Construct a URL by concatenating a base part with one or more path segments. This function
ensures that each segment is separated by a single forward slash (`/`), regardless of whether
the `basepart` or `parts` already contain slashes at their boundaries.

## Examples

```julia-repl
julia> EasyCurl.joinurl("http://example.com", "path")
"http://example.com/path"

julia> EasyCurl.joinurl("http://example.com/", "/path/to/resource")
"http://example.com/path/to/resource"
```
"""
function joinurl(basepart::AbstractString, parts::AbstractString...)::String
    basepart = endswith(basepart, "/") ? basepart[1:end-1] : basepart
    parts = filter(!isempty, parts)
    parts = map(p -> startswith(p, "/") ? p[2:end] : p, parts)
    parts = map(p -> endswith(p, "/") ? p[1:end-1] : p, parts)
    return join([basepart, parts...], "/")
end

function parse_headers(x::AbstractString)
    hdrs = Pair{String,String}[]
    for m in match.(r"^(.*?):\s*(.*?)$", split(x, "\r\n"))
        isnothing(m) && continue
        push!(hdrs, lowercase(m[1]) => m[2])
    end
    return hdrs
end

function parse_headers(x::Vector{UInt8})
    return parse_headers(unsafe_string(pointer(x), length(x)))
end

to_query_decode(curl, ::Nothing) = ""
to_query_decode(curl, x::S) where {S<:AbstractString} = x
to_query_decode(curl, x::AbstractDict) = urlencode_query_params(curl, x)

function req_url(curl, url::AbstractString, query)
    kv = to_query_decode(curl, query)
    return isempty(kv) ? url : url * "?" * kv
end

to_bytes(::Nothing) = Vector{UInt8}()
to_bytes(x::S) where {S<:AbstractString} = Vector{UInt8}(x)
to_bytes(x::Vector{UInt8}) = x
