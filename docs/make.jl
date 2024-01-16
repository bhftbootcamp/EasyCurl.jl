using EasyCurl
using Documenter

DocMeta.setdocmeta!(EasyCurl, :DocTestSetup, :(using EasyCurl); recursive = true)

makedocs(;
    modules = [EasyCurl],
    repo = "https://github.com/bhftbootcamp/EasyCurl.jl/blob/{commit}{path}#{line}",
    sitename = "EasyCurl.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://bhftbootcamp.github.io/EasyCurl.jl",
        edit_link = "master",
        assets = String["assets/favicon.ico"],
        repolink = "https://github.com/bhftbootcamp/EasyCurl.jl.git",
    ),
    pages = [
        "Home" => "index.md",
        "API Reference" => "pages/api_reference.md",
        "Constants" => "pages/constants.md",
        "For Developers" => "pages/error_handling.md",
    ],
)

deploydocs(; repo = "github.com/bhftbootcamp/EasyCurl.jl", devbranch = "master")
