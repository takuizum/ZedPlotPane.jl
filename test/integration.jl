# Integration tests that exercise ZedDisplay against *real* plotting and data
# libraries, verifying that the text/html discrimination (see _is_interactive_html)
# routes each kind of object to the right place:
#
#   * interactive web plots (Plotly, Gadfly, ...) -> opened in the browser
#   * static HTML tables (DataFrames, pandas, polars) -> declined so the REPL
#     falls back to text/plain (this is the bug these tests guard against)
#   * raster/vector plots (GR, CairoMakie)           -> written as an image file
#
# Every library is loaded optionally: a missing dependency (e.g. no usable
# Python for PythonCall) skips its testset instead of failing the suite. This
# lets the file run both under `Pkg.test()` (Julia deps present) and under
# `julia --project=example test/runtests.jl` (PythonCall + pandas/polars
# present). `ENV["ZED_PLOT_PANE_TESTING"]` is already "true" (set in
# runtests.jl), so no real browser/viewer is launched.

using Test
using ZedPlotPane

const _D = ZedPlotPane.ZedDisplay()
const _HTML = ZedPlotPane.plot_path("html")

# Optionally import a module by name; return whether it succeeded. Must be
# called at top level (before any @testset) so the imported methods are in an
# older world age than the testset bodies that use them.
function _try_import(mod::Symbol)
    try
        @eval import $mod
        return true
    catch e
        @info "integration: `$mod` unavailable — skipping its testset" exception = e
        return false
    end
end

# Resolve all optional dependencies up front, at top level.
const HAS_DATAFRAMES = _try_import(:DataFrames)
const HAS_GADFLY = _try_import(:Gadfly)
const HAS_PLOTS = _try_import(:Plots)
const HAS_CAIROMAKIE = _try_import(:CairoMakie)

# The PythonCall tests need a real Python with pandas/polars. They are opt-in:
# set ZEDPLOTPANE_TEST_PYTHON=true (and point PythonCall at your interpreter,
# e.g. JULIA_PYTHONCALL_EXE=/path/to/venv/bin/python JULIA_CONDAPKG_BACKEND=Null).
# Without the opt-in we don't even import PythonCall, so plain CI never triggers
# a CondaPkg/conda download.
const RUN_PYTHON = get(ENV, "ZEDPLOTPANE_TEST_PYTHON", "false") == "true"
const HAS_PYTHONCALL = RUN_PYTHON && _try_import(:PythonCall)

# Write a unique sentinel into the html cache so we can detect whether a later
# display() call wrote to it.
function _seed_html()
    s = "SENTINEL-" * string(rand(UInt32))
    write(_HTML, s)
    return s
end

"x must be declined by ZedDisplay (MethodError) and leave the html cache untouched."
function expect_decline(x)
    s = _seed_html()
    @test showable(MIME("text/html"), x)                 # it *is* html-showable ...
    html = sprint(io -> show(io, MIME("text/html"), x))
    @test !ZedPlotPane._is_interactive_html(html)         # ... but not interactive
    @test_throws MethodError display(_D, x)
    @test read(_HTML, String) == s                        # cache not overwritten
end

"x must be opened as an interactive HTML plot (browser branch)."
function expect_browser_html(x)
    s = _seed_html()
    @test display(_D, x) === nothing                      # handled, no throw
    out = read(_HTML, String)
    @test out != s                                        # real plot written
    @test ZedPlotPane._is_interactive_html(out)
end

"x must be written as an image file `ext` (viewer branch), leaving html untouched."
function expect_image(x, ext)
    path = ZedPlotPane.plot_path(ext)
    isfile(path) && rm(path)
    s = _seed_html()
    @test display(_D, x) === nothing
    @test isfile(path) && filesize(path) > 0              # image written
    @test read(_HTML, String) == s                        # html cache not touched
end

@testset "Integration: real libraries" begin

    @testset "DataFrames.jl table -> text fallback (no browser)" begin
        if HAS_DATAFRAMES
            df = DataFrames.DataFrame(a = 1:3, b = 4:6)
            expect_decline(df)
        else
            @test_skip false
        end
    end

    @testset "Gadfly plot -> browser (interactive HTML)" begin
        if HAS_GADFLY
            g = Gadfly.plot(x = 1:10, y = collect(1:10), Gadfly.Geom.line)
            expect_browser_html(g)
        else
            @test_skip false
        end
    end

    @testset "Plots.jl plotly backend -> browser (interactive HTML)" begin
        if HAS_PLOTS
            ok = try
                Plots.plotly()
                true
            catch e
                @info "integration: Plots plotly backend unavailable" exception = e
                false
            end
            if ok
                p = Plots.plot(1:10, collect(1:10))
                expect_browser_html(p)
            else
                @test_skip false
            end
        else
            @test_skip false
        end
    end

    @testset "Plots.jl GR backend -> image file (png)" begin
        if HAS_PLOTS
            Plots.gr()
            p = Plots.plot(1:10, collect(1:10))
            expect_image(p, "png")
        else
            @test_skip false
        end
    end

    @testset "CairoMakie figure -> image file (png)" begin
        if HAS_CAIROMAKIE
            f = CairoMakie.Figure()
            CairoMakie.Axis(f[1, 1])
            CairoMakie.lines!(1:10, collect(1:10))
            expect_image(f, "png")
        else
            @test_skip false
        end
    end

    @testset "PythonCall: pandas / polars tables -> text fallback (no browser)" begin
        py_ok = HAS_PYTHONCALL && try
            PythonCall.pyimport("sys")           # force runtime init
            true
        catch e
            @info "integration: PythonCall has no usable Python — skipping" exception = e
            false
        end

        if !py_ok
            @test_skip false
        else
            tested_any = false
            for lib in ("pandas", "polars")
                mod = try
                    PythonCall.pyimport(lib)
                catch e
                    @info "integration: Python `$lib` not installed — skipping" exception = e
                    nothing
                end
                mod === nothing && continue
                tested_any = true
                @testset "$lib DataFrame" begin
                    df = mod.DataFrame(PythonCall.pydict(Dict("a" => [1, 2, 3], "b" => [4, 5, 6])))
                    expect_decline(df)
                end
            end
            tested_any || @test_skip false
        end
    end

end
