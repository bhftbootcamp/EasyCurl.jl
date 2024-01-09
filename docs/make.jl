using cURL
using Documenter

DocMeta.setdocmeta!(cURL, :DocTestSetup, :(using cURL); recursive = true)

makedocs(;
    modules = [cURL],
    repo = "https://github.com/bhftbootcamp/cURL.jl/blob/{commit}{path}#{line}",
    sitename = "cURL.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://bhftbootcamp.github.io/cURL.jl",
        edit_link = "master",
        assets = String["assets/favicon.ico"],
        repolink = "https://github.com/bhftbootcamp/cURL.jl.git",
    ),
    pages = [
        "Home" => "index.md",
        "API Reference" => "pages/api_reference.md",
        "Constants" => "pages/constants.md",
    ],
)

deploydocs(; repo = "github.com/bhftbootcamp/cURL.jl", devbranch = "master")
