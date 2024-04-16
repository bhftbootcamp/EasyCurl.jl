using EasyCurl
using Documenter

DocMeta.setdocmeta!(EasyCurl, :DocTestSetup, :(using EasyCurl); recursive = true)

makedocs(;
    modules = [EasyCurl],
    sitename = "EasyCurl.jl",
    format = Documenter.HTML(;
        repolink = "https://github.com/bhftbootcamp/EasyCurl.jl",
        canonical = "https://bhftbootcamp.github.io/EasyCurl.jl",
        edit_link = "master",
        assets = String["assets/favicon.ico"],
        sidebar_sitename = true,
    ),
    pages = [
        "Home" => "index.md",
        "API Reference" => "pages/api_reference.md",
        "Constants" => "pages/constants.md",
        "For Developers" => "pages/error_handling.md",
    ],
    warnonly = [:doctest, :missing_docs],
)

deploydocs(;
    repo = "github.com/bhftbootcamp/EasyCurl.jl",
    devbranch = "master",
    push_preview = true,
)
