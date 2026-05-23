using Test
using ZedPlotPane

# Ensure we don't open actual windows/browsers during testing
ENV["ZED_PLOT_PANE_TESTING"] = "true"

@testset "ZedPlotPane basics" begin
    @test occursin(".cache/zed-julia/current-plot.png", ZedPlotPane.plot_path())
    @test occursin(".cache/zed-julia/current-plot.svg", ZedPlotPane.plot_path("svg"))
    @test occursin(".cache/zed-julia/current-plot.html", ZedPlotPane.plot_path("html"))
    @test occursin(".cache/zed-julia/current-plot.jpg", ZedPlotPane.plot_path("jpg"))
    @test occursin(".cache/zed-julia/current-plot.gif", ZedPlotPane.plot_path("gif"))
    
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

struct MockHTML end
Base.showable(::MIME"text/html", ::MockHTML) = true
Base.show(io::IO, ::MIME"text/html", ::MockHTML) = write(io, "html-data")

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
    @test read(ZedPlotPane.plot_path("html"), String) == "html-data"

    display(d, MockJPEG())
    @test read(ZedPlotPane.plot_path("jpg"), String) == "jpeg-data"

    display(d, MockGIF())
    @test read(ZedPlotPane.plot_path("gif"), String) == "gif-data"
end

@testset "open_pane" begin
    # Should not throw even if 'zed' is missing
    @test_nowarn open_pane()
end
