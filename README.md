# ZedPlotPane.jl

Julia-side runtime for plot-pane integration in the [Zed editor](https://zed.dev).
Renders plots from `Plots.jl`, `Makie.jl`, `Images.jl`, and any library with
`image/png` or `image/svg+xml` MIME support into a persistent side pane in Zed
via the image viewer — no Jupyter, no IJulia, no separate GUI window.

![ZedPlotPane in action](https://github.com/user-attachments/assets/3681b379-cf0d-4157-8acc-be2aa0290b77)

## How it works

A custom `ZedDisplay <: AbstractDisplay` is registered via `pushdisplay()`. Every
plot overwrites a single fixed file (`~/.cache/zed-julia/current-plot.png`); Zed's
image viewer detects the change via its built-in `fs::watch()` and reloads the
pane in ~100 ms — no CLI invocation, no focus change.

Plotting libraries such as `Plots.jl` call `pushdisplay()` in their `__init__`,
which would bury `ZedDisplay` below their own display. A `Base.package_callbacks`
hook re-promotes `ZedDisplay` to the top after each package load so it always
takes priority.

Use it together with the [`zed-julia`](https://github.com/JuliaEditorSupport/zed-julia)
extension, which ships the `Julia: Open Plot Pane` task for opening the plot file
from Zed's command palette.

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
