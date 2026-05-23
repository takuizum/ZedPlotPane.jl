using Test
using ZedPlotPane

@testset "ZedPlotPane basics" begin
    @test occursin(".cache/zed-julia/current-plot.png", ZedPlotPane.plot_path())
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

@testset "open_pane" begin
    # Should not throw even if 'zed' is missing
    @test_nowarn open_pane()
end
