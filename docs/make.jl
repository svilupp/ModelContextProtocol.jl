using ModelContextProtocol
using Documenter

DocMeta.setdocmeta!(ModelContextProtocol, :DocTestSetup, :(using ModelContextProtocol); recursive=true)

makedocs(;
    modules=[ModelContextProtocol],
    authors="J S <49557684+svilupp@users.noreply.github.com> and contributors",
    sitename="ModelContextProtocol.jl",
    format=Documenter.HTML(;
        canonical="https://svilupp.github.io/ModelContextProtocol.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/svilupp/ModelContextProtocol.jl",
    devbranch="main",
)
