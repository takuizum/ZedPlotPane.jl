using Random
using ZedPlotPane
using Gadfly

Random.seed!(99)

ZedPlotPane.setup_display!()
ZedPlotPane._open_viewer()

x = collect(1:80)
for i in 1:5
    y = cumsum(randn(length(x)) .* 0.15) .+ 0.4 * i
    p = plot(
        x=x,
        y=y,
        Geom.line,
        Guide.title("Gadfly update #$i"),
        Guide.xlabel("index"),
        Guide.ylabel("value"),
    )
    display(p)
    sleep(0.8)
end
