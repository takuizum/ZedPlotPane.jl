# ZedPlotPane.jl

`ZedPlotPane.jl` is the Julia-side library for Zed plot-pane integration.
It installs a custom display that writes plot output to `~/.cache/zed-julia/current-plot.png`
and keeps that display on top so pane updates remain stable even after plotting packages load.

## Installation (before General registration)

This package is currently installed directly from GitHub.

```julia
using Pkg
Pkg.add(url = "https://github.com/takuizum/ZedPlotPane.jl")
```

For reproducibility, pin to a tag or commit:

```julia
Pkg.add(url = "https://github.com/takuizum/ZedPlotPane.jl", rev = "v0.1.0")
# or: rev = "<commit-sha>"
```

## Basic usage

```julia
using ZedPlotPane

ZedPlotPane.setup_display!()
println(ZedPlotPane.plot_path())
```

## Plots.jl example

```julia
using ZedPlotPane
using Plots

ZedPlotPane.setup_display!()
plot(1:10, rand(10), title = "Plots.jl in Zed")
```

## Makie.jl example

```julia
using ZedPlotPane
using CairoMakie

ZedPlotPane.setup_display!()
f = Figure()
Axis(f[1, 1])
lines!(1:10, rand(10))
display(f)
```

## Auto-init behavior

Auto-init is enabled by default in interactive Julia sessions.

```julia
ZedPlotPane.auto_init_enabled()
ZedPlotPane.disable_auto_init!()
ZedPlotPane.enable_auto_init!()
```

## Notes

- If `zed` CLI is unavailable, images are still written to `plot_path()`.
- Zed extension-specific task/config files stay in `zed-julia`, not in this package.
