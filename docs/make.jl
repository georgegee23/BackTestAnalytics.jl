using BackTestAnalytics
using Documenter

DocMeta.setdocmeta!(BackTestAnalytics, :DocTestSetup, :(using BackTestAnalytics); recursive=true)

makedocs(;
    modules=[BackTestAnalytics],
    authors="georgeg <georgegi86@gmail.com> and contributors",
    sitename="BackTestAnalytics.jl",
    format=Documenter.HTML(;
        canonical="https://georgegee23.github.io/BackTestAnalytics.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/georgegee23/BackTestAnalytics.jl",
    devbranch="master",
)
