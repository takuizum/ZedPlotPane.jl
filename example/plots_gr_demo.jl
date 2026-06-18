using Random
using ZedPlotPane
using Plots

Random.seed!(42)
gr()

ZedPlotPane.setup_display!()
ZedPlotPane._open_viewer()

x = 0:0.1:10
for i in 1:5
    y = @. sin(x + 0.3 * i) + 0.15 * randn()
    p = plot(x, y; title="Plots.jl (GR) update #$i", xlabel="x", ylabel="y", legend=false, lw=2)
    display(p)
    sleep(0.8)
end
