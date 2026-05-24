using Random
using ZedPlotPane
using CairoMakie

Random.seed!(7)

ZedPlotPane.setup_display!()
ZedPlotPane._open_viewer()

x = range(0, 2pi; length=400)
for i in 1:5
    fig = Figure(size=(800, 500))
    ax = Axis(fig[1, 1], title="CairoMakie update #$i", xlabel="x", ylabel="f(x)")
    lines!(ax, x, sin.(x .+ 0.25 * i); linewidth=3)
    lines!(ax, x, 0.5 .* cos.(2 .* x .- 0.2 * i); linewidth=2)
    display(fig)
    sleep(0.8)
end
