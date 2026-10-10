using Test
using ZedPlotPane
using Preferences

# Ensure we don't open actual windows/browsers during testing
ENV["ZED_PLOT_PANE_TESTING"] = "true"

@testset "ZedPlotPane basics" begin
    # Helper to check if path contains expected components regardless of separators
    function contains_path_parts(full_path, parts...)
        normalized = replace(full_path, "\\" => "/")
        expected = join(parts, "/")
        return occursin(expected, normalized)
    end

    @test contains_path_parts(ZedPlotPane.plot_path(), ".cache", "zed-julia", "current-plot.png")
    @test contains_path_parts(ZedPlotPane.plot_path("svg"), ".cache", "zed-julia", "current-plot.svg")
    @test contains_path_parts(ZedPlotPane.plot_path("html"), ".cache", "zed-julia", "current-plot.html")
    @test contains_path_parts(ZedPlotPane.plot_path("jpg"), ".cache", "zed-julia", "current-plot.jpg")
    @test contains_path_parts(ZedPlotPane.plot_path("gif"), ".cache", "zed-julia", "current-plot.gif")

    d = ZedPlotPane.ZedDisplay()
    @test displayable(d, MIME("image/png"))
    @test displayable(d, MIME("image/jpeg"))
    @test displayable(d, MIME("image/gif"))
    @test displayable(d, MIME("text/html"))
    @test displayable(d, MIME("image/svg+xml"))
    @test !displayable(d, MIME("text/plain"))
end

@testset "auto-init controls" begin
    original = ZedPlotPane.auto_init_enabled()
    try
        ZedPlotPane.disable_auto_init!()
        @test !ZedPlotPane.auto_init_enabled()
        ZedPlotPane.enable_auto_init!()
        @test ZedPlotPane.auto_init_enabled()
    finally
        original ? ZedPlotPane.enable_auto_init!() : ZedPlotPane.disable_auto_init!()
    end
end

@testset "explicit public setup functions" begin
    displays = Base.Multimedia.displays
    before = count(d -> d isa ZedPlotPane.ZedDisplay, displays)
    try
        # Test split functions
        ZedPlotPane.setup_environment!()
        @test isfile(ZedPlotPane.plot_path("png"))
        @test isfile(ZedPlotPane.plot_path("svg"))
        @test isfile(ZedPlotPane.plot_path("html"))
        @test isfile(ZedPlotPane.plot_path("gif"))
        @test ENV["MPLBACKEND"] == "Agg"

        ZedPlotPane.register_display!()
        @test count(d -> d isa ZedPlotPane.ZedDisplay, displays) == before + (before == 0 ? 1 : 0)
    finally
        while count(d -> d isa ZedPlotPane.ZedDisplay, displays) > before
            idx = findfirst(d -> d isa ZedPlotPane.ZedDisplay, displays)
            idx === nothing && break
            splice!(displays, idx)
        end
    end
end

@testset "display registration is idempotent" begin
    displays = Base.Multimedia.displays
    before = count(d -> d isa ZedPlotPane.ZedDisplay, displays)
    try
        ZedPlotPane.setup_display!()
        after_first = count(d -> d isa ZedPlotPane.ZedDisplay, displays)
        ZedPlotPane.setup_display!()
        after_second = count(d -> d isa ZedPlotPane.ZedDisplay, displays)

        @test after_first == before + (before == 0 ? 1 : 0)
        @test after_second == after_first
        @test displays[end] isa ZedPlotPane.ZedDisplay
    finally
        while count(d -> d isa ZedPlotPane.ZedDisplay, displays) > before
            idx = findfirst(d -> d isa ZedPlotPane.ZedDisplay, displays)
            idx === nothing && break
            splice!(displays, idx)
        end
    end
end

# Define mock structs to test display outputs for various MIME types
struct MockPNG end
Base.showable(::MIME"image/png", ::MockPNG) = true
Base.show(io::IO, ::MIME"image/png", ::MockPNG) = write(io, "png-data")

struct MockSVG end
Base.showable(::MIME"image/svg+xml", ::MockSVG) = true
Base.show(io::IO, ::MIME"image/svg+xml", ::MockSVG) = write(io, "svg-data")

# Interactive plot: HTML containing JavaScript -> should open in the browser.
struct MockHTML end
Base.showable(::MIME"text/html", ::MockHTML) = true
Base.show(io::IO, ::MIME"text/html", ::MockHTML) = write(io, "<div><script>Plotly.newPlot()</script></div>")

# Static HTML (e.g. a pandas/polars/DataFrames table): pure markup, no JS ->
# must NOT open the browser and must fall through to text/plain.
struct MockTable end
Base.showable(::MIME"text/html", ::MockTable) = true
Base.show(io::IO, ::MIME"text/html", ::MockTable) = write(io, "<table><tr><td>1</td></tr></table>")

struct MockJPEG end
Base.showable(::MIME"image/jpeg", ::MockJPEG) = true
Base.show(io::IO, ::MIME"image/jpeg", ::MockJPEG) = write(io, "jpeg-data")

struct MockGIF end
Base.showable(::MIME"image/gif", ::MockGIF) = true
Base.show(io::IO, ::MIME"image/gif", ::MockGIF) = write(io, "gif-data")

@testset "display support for multiple MIME types" begin
    # Ensure display works for MockPNG
    d = ZedPlotPane.ZedDisplay()

    display(d, MockPNG())
    @test read(ZedPlotPane.plot_path("png"), String) == "png-data"

    display(d, MockSVG())
    @test read(ZedPlotPane.plot_path("svg"), String) == "svg-data"

    display(d, MockHTML())
    @test read(ZedPlotPane.plot_path("html"), String) == "<div><script>Plotly.newPlot()</script></div>"

    display(d, MockJPEG())
    @test read(ZedPlotPane.plot_path("jpg"), String) == "jpeg-data"

    display(d, MockGIF())
    @test read(ZedPlotPane.plot_path("gif"), String) == "gif-data"
end

@testset "interactive HTML detection" begin
    @test ZedPlotPane._is_interactive_html("<div><script>x()</script></div>")
    @test ZedPlotPane._is_interactive_html("<iframe srcdoc=\"...\"></iframe>")
    @test ZedPlotPane._is_interactive_html("<SCRIPT>x()</SCRIPT>")  # case-insensitive
    @test !ZedPlotPane._is_interactive_html("<table><tr><td>1</td></tr></table>")
    @test !ZedPlotPane._is_interactive_html("<div><style>.a{}</style><table></table></div>")
end

@testset "static HTML tables do not open a browser" begin
    d = ZedPlotPane.ZedDisplay()
    # Seed the cache file with a sentinel so we can detect an unwanted overwrite.
    sentinel = "SENTINEL-DO-NOT-OVERWRITE"
    write(ZedPlotPane.plot_path("html"), sentinel)

    # MockTable is only showable as text/html and contains no JS, so ZedDisplay
    # must decline it (MethodError) -> the REPL falls back to text/plain.
    @test_throws MethodError display(d, MockTable())
    # The cache file must be untouched (no spurious HTML write).
    @test read(ZedPlotPane.plot_path("html"), String) == sentinel
end

@testset "open_pane" begin
    # Should not throw even if 'zed' is missing
    @test_nowarn open_pane()
end

@testset "clear_pane" begin
    # Write dirty data to mock active plots
    write(ZedPlotPane.plot_path("png"), "dirty-png")
    write(ZedPlotPane.plot_path("svg"), "dirty-svg")
    write(ZedPlotPane.plot_path("html"), "dirty-html")
    write(ZedPlotPane.plot_path("gif"), "dirty-gif")

    @test_nowarn clear_pane()

    @test read(ZedPlotPane.plot_path("png")) == ZedPlotPane.BLANK_PNG
    @test read(ZedPlotPane.plot_path("svg"), String) == ZedPlotPane.BLANK_SVG
    @test read(ZedPlotPane.plot_path("html"), String) == ZedPlotPane.BLANK_HTML
    @test read(ZedPlotPane.plot_path("gif")) == ZedPlotPane.BLANK_GIF
end

@testset "named plot targets (multi-pane)" begin
    # Initial target should be current-plot
    @test ZedPlotPane.plot_target() == "current-plot"

    try
        # Set a new target
        @test ZedPlotPane.set_plot_target!("figure2") == "figure2"
        @test ZedPlotPane.plot_target() == "figure2"
        @test occursin("figure2.png", ZedPlotPane.plot_path())
        @test occursin("figure2.svg", ZedPlotPane.plot_path("svg"))

        # Writing mock plot to figure2
        d = ZedPlotPane.ZedDisplay()
        display(d, MockPNG())
        @test isfile(ZedPlotPane.plot_path("png"))
        @test read(ZedPlotPane.plot_path("png"), String) == "png-data"

        # clear_pane clears figure2
        clear_pane()
        @test read(ZedPlotPane.plot_path("png")) == ZedPlotPane.BLANK_PNG

        # open_pane with target
        @test_nowarn open_pane("figure3")
        @test ZedPlotPane.plot_target() == "figure3"
        @test occursin("figure3.png", ZedPlotPane.plot_path())

        # Validation checks
        @test_throws ArgumentError ZedPlotPane.set_plot_target!("")
        @test_throws ArgumentError ZedPlotPane.set_plot_target!("sub/dir")
        @test_throws ArgumentError ZedPlotPane.set_plot_target!("sub\\dir")
    finally
        # Reset target back to current-plot
        ZedPlotPane.reset_plot_target!()
        @test ZedPlotPane.plot_target() == "current-plot"
        @test occursin("current-plot.png", ZedPlotPane.plot_path())
    end
end

@testset "cache_dir configuration" begin
    orig_dir = ZedPlotPane.cache_dir()
    tmpdir = mktempdir()
    try
        @test ZedPlotPane.set_cache_dir!(tmpdir) == tmpdir
        @test ZedPlotPane.cache_dir() == tmpdir
        @test startswith(ZedPlotPane.plot_path(), tmpdir)
        @test ZedPlotPane.history_dir() == joinpath(tmpdir, "history")
    finally
        ZedPlotPane.set_cache_dir!(orig_dir)
        rm(tmpdir; recursive=true, force=true)
    end
end

@testset "plot history" begin
    orig_dir = ZedPlotPane.cache_dir()
    orig_hist = ZedPlotPane.history_enabled()
    tmpdir = mktempdir()
    try
        ZedPlotPane.set_cache_dir!(tmpdir)
        ZedPlotPane.disable_history!()
        @test !ZedPlotPane.history_enabled()
        ZedPlotPane.enable_history!()
        @test ZedPlotPane.history_enabled()

        d = ZedPlotPane.ZedDisplay()
        display(d, MockPNG())

        hdir = ZedPlotPane.history_dir()
        @test isdir(hdir)
        png_files = filter(f -> endswith(f, ".png"), readdir(hdir))
        @test length(png_files) == 1
        @test startswith(png_files[1], "current-plot_")

        display(d, MockHTML())
        html_files = filter(f -> endswith(f, ".html"), readdir(hdir))
        @test length(html_files) == 1
        @test startswith(html_files[1], "current-plot_")

        # Disable history and ensure no new history file is created
        ZedPlotPane.disable_history!()
        @test !ZedPlotPane.history_enabled()
        display(d, MockGIF())
        gif_files = filter(f -> endswith(f, ".gif"), readdir(hdir))
        @test isempty(gif_files)
    finally
        orig_hist ? ZedPlotPane.enable_history!() : ZedPlotPane.disable_history!()
        ZedPlotPane.set_cache_dir!(orig_dir)
        rm(tmpdir; recursive=true, force=true)
    end
end

@testset "persistent preferences" begin
    orig_dir = ZedPlotPane.cache_dir()
    orig_init = ZedPlotPane.auto_init_enabled()
    orig_hist = ZedPlotPane.history_enabled()
    tmpdir = mktempdir()
    try
        ZedPlotPane.set_persistent_cache_dir!(tmpdir)
        @test ZedPlotPane.cache_dir() == tmpdir
        # Confirm the preference was actually persisted (e.g. to
        # LocalPreferences.toml), not just reflected in the in-memory Ref.
        @test Preferences.load_preference(ZedPlotPane, "cache_dir") == tmpdir

        ZedPlotPane.set_persistent_auto_init!(false)
        @test !ZedPlotPane.auto_init_enabled()
        @test Preferences.load_preference(ZedPlotPane, "auto_init") == false

        ZedPlotPane.set_persistent_history!(true)
        @test ZedPlotPane.history_enabled()
        @test Preferences.load_preference(ZedPlotPane, "history") == true

        # `Preferences.load_preference` above round-trips through whatever
        # file Preferences.jl actually wrote to (its resolution of "the
        # project that depends on this package" does not always match
        # `dirname(Base.active_project())` — e.g. under `Pkg.test()`'s
        # sandboxed temp environment it can resolve to the package's own
        # directory instead). That round-trip is sufficient to catch a
        # silently-failing `@set_preferences!` call without hardcoding or
        # guessing Preferences.jl's internal file layout.
    finally
        ZedPlotPane.set_persistent_cache_dir!(orig_dir)
        ZedPlotPane.set_persistent_auto_init!(orig_init)
        ZedPlotPane.set_persistent_history!(orig_hist)
        rm(tmpdir; recursive=true, force=true)
    end
end

# Integration tests against real plotting/data libraries (optional deps inside).
include("integration.jl")
