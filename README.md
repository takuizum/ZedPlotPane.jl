# ZedPlotPane.jl

Julia-side runtime for plot-pane integration in the [Zed editor](https://zed.dev).
Renders plots from `Plots.jl`, `Makie.jl`, `Images.jl`, and any library with
`image/png`, `image/svg+xml`, `image/jpeg`, or `text/html` MIME support into a persistent side pane in Zed (or your system web browser for dynamic plots) — no Jupyter, no IJulia, no separate GUI window.

![ZedPlotPane in action](https://github.com/user-attachments/assets/3681b379-cf0d-4157-8acc-be2aa0290b77)

## How it works

A custom `ZedDisplay <: AbstractDisplay` is registered via `pushdisplay()`. Every
plot overwrites a format-specific cache file (`~/.cache/zed-julia/current-plot.<ext>` where `<ext>` is `png`, `svg`, `jpg`, or `html`).

- **Static plots (PNG, SVG, JPEG)**: Opened in Zed's viewer. When the file changes, Zed's editor detects the change via its built-in `fs::watch()` and reloads the pane in ~100 ms — no CLI invocation, no focus change.
- **Dynamic/Interactive plots (HTML)**: Opened automatically in your system's default web browser (as Zed does not natively support webviews).

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

- If the `zed` command is not available in your `PATH`, the package automatically searches for `/Applications/Zed.app/Contents/MacOS/cli` and falls back to using the macOS `open -a Zed` command.
- You can override or specify a custom Zed CLI path by setting the `ZED_CLI_PATH` environment variable.
- Zed extension-specific task/config files stay in `zed-julia`, not in this package.

