using Documenter, Literate

const PROJECT_DIR     = normpath(@__DIR__, "..")
const README_FILENAME = normpath(PROJECT_DIR, "README.md")
const SRC_DIR         = normpath(PROJECT_DIR, "src")
const DOC_SRC_DIR     = normpath(@__DIR__, "src")
const INDEX_FILENAME  = normpath(DOC_SRC_DIR, "index.md")
const NOTEBOOKS_DIR   = normpath(DOC_SRC_DIR, "notebooks")

function generate_index()
    isfile(INDEX_FILENAME) && rm(INDEX_FILENAME)
    open(INDEX_FILENAME, write=true) do io
        write(io, read(README_FILENAME))
    end

    return relpath(INDEX_FILENAME, DOC_SRC_DIR)
end

function postprocess(f)
    return function (s)
        # fix relative links
        if get(ENV, "CI", nothing) == "true"
            s = replace(s, r"\(\./(.+).ipynb\)" => s"(../../\1/)")
        else
            s = replace(s, r"\(\./(.+).ipynb\)" => s"(../\1.html)")
        end

        # fix equation syntax
        open = false
        s = replace(s, r"\$\$" => function (_)
            open = !open
            open ? "```math" : "```"
        end)

        return """
        ```@setup $(first(splitext(basename(f))))
        using Pkg
        Pkg.activate("$PROJECT_DIR")
        Pkg.instantiate()
        for f in ["utils.jl"]
            cp(normpath("$SRC_DIR", f), normpath(@__DIR__, f), force = true)
        end
        ```
        """ * s
    end
end

function generate_notebooks()
    isdir(NOTEBOOKS_DIR) && rm(NOTEBOOKS_DIR; recursive = true)
    ret = []

    for (n, f) in ["Intro" => "intro.jl",
                   "Back & Forth" => "backandforth.jl",
                   "Forward" => "forward.jl",
                   "Tracing" => "tracing.jl",
                   "Reverse" => "reverse.jl"]
        out = Literate.markdown(normpath(SRC_DIR, f), NOTEBOOKS_DIR;
                                postprocess = postprocess(f),
                                credit = false,
                                documenter = true)
        push!(ret, n => relpath(out, DOC_SRC_DIR))
    end

    return ret
end

let
    makedocs(; sitename="diff-zoo",
               pages = [
                    "README" => generate_index(),
                    "Notebooks" => Any[generate_notebooks()...]
               ],
               format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
               )
end

deploydocs(; repo = "github.com/aviatesk/diff-zoo.git",
             push_preview = true,
             )
