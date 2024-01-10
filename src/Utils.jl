# Utils

"""
    Curl.urlencode(s::AbstractString)

Encode a string `s` into URI using only the US-ASCII characters legal within a URI.

## Examples

```julia-repl
julia> Curl.urlencode("[curl]")
"%5Bcurl%5D"
```
"""
function urlencode(s::AbstractString)
    return urlencode_query(curl_easy_init(), s)
end

function urlencode_query(curl, s::AbstractString)
    b_arr = curl_easy_escape(curl, s, sizeof(s))
    esc_s = unsafe_string(b_arr)
    curl_free(b_arr)
    return esc_s
end

function urlencode_query_params(params::AbstractDict{String,T}) where {T<:Any}
    str = ""
    for (k, v) in params
        if v !== ""
            ep = urlencode(string(k)) * "=" * urlencode(string(v))
        else
            ep = urlencode(string(k))
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
    Curl.urldecode(s::AbstractString)

Decode an encoded URI string `s` back to normal string.

## Examples

```julia-repl
julia> Curl.urldecode("%5Bcurl%5D")
"[curl]"
```
"""
function urldecode(s::AbstractString)
    return urldecode_query(curl_easy_init(), s)
end

function urldecode_query(curl, s::AbstractString)
    b_arr = curl_easy_unescape(curl, s, 0, C_NULL)
    esc_s = unsafe_string(b_arr)
    curl_free(b_arr)
    return esc_s
end

"""
    Curl.joinurl(basepart::AbstractString, parts::AbstractString...)::String

Construct a URL by concatenating a base part with one or more path segments. This function
ensures that each segment is separated by a single forward slash (`/`), regardless of whether
the `basepart` or `parts` already contain slashes at their boundaries.

## Examples

```julia-repl
julia> Curl.joinurl("http://example.com", "path")
"http://example.com/path"

julia> Curl.joinurl("http://example.com/", "/path/to/resource")
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

function parse_headers(headers::AbstractString)
    matches = match.(r"^(.*?):\s*(.*?)$", split(headers, "\r\n"))
    result = Pair{String,String}[]
    for m in matches
        isnothing(m) && continue
        push!(result, m[1] => m[2])
    end
    return result
end
