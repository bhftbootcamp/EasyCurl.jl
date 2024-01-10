using Curl
using Documenter

DocMeta.setdocmeta!(Curl, :DocTestSetup, :(using Curl); recursive = true)

makedocs(;
    modules = [Curl],
    repo = "https://github.com/bhftbootcamp/Curl.jl/blob/{commit}{path}#{line}",
    sitename = "Curl.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://bhftbootcamp.github.io/Curl.jl",
        edit_link = "master",
        assets = String["assets/favicon.ico"],
        repolink = "https://github.com/bhftbootcamp/Curl.jl.git",
    ),
    pages = [
        "Home" => "index.md",
        "API Reference" => "pages/api_reference.md",
        "Constants" => "pages/constants.md",
    ],
)

deploydocs(; repo = "github.com/bhftbootcamp/Curl.jl", devbranch = "master")
