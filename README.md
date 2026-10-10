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
extension.


## Installation

### Install from the official registry (General)

```julia
using Pkg
Pkg.add("ZedPlotPane")
```

### Install the development version from GitHub

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

## Matplotlib / PythonCall example

```julia
using ZedPlotPane
using PythonCall

ZedPlotPane.setup_display!()
plt = pyimport("matplotlib.pyplot")
plt.plot(1:10, rand(10))
display(plt.gcf())
```

> **Note**: For Matplotlib, `ZedPlotPane` automatically sets `ENV["MPLBACKEND"] = "Agg"` to capture plots. If you use `PythonCall.jl` or `PyCall.jl`, make sure to call `display(plt.gcf())` to send the current figure to the Zed Plot Pane.
>
> If your environment cannot download Python via Conda (for example, due to a firewall), set `JULIA_PYTHONCALL_EXE` to a system Python (for example, `python` or `python3`) before starting Julia.

## Auto-init behavior

Auto-init is enabled by default in interactive Julia sessions.

```julia
ZedPlotPane.auto_init_enabled()
ZedPlotPane.disable_auto_init!()
ZedPlotPane.enable_auto_init!()
```

## Redisplaying the plot pane

If you close the plot pane in Zed, you can reopen it manually without waiting for the next plot:

```julia
using ZedPlotPane
open_pane()
```

## Clearing the plot pane

You can programmatically clear the plot pane to reset the view:

```julia
using ZedPlotPane
clear_pane()
```

## Named Plot Panes (Multi-pane support)

Route plots to different files to open multiple plots in separate tabs or side-by-side split panes in Zed:

```julia
using ZedPlotPane

# Route subsequent plots to "figure2.png"
set_plot_target!("figure2")
# plot(...) -> updates ~/.cache/zed-julia/figure2.png

# Revert to the default target ("current-plot.png")
reset_plot_target!()
```

You can also open or switch targets directly:

```julia
open_pane("figure2")
```

## Plot History

Save timestamped copies of your plots automatically (stored in `~/.cache/zed-julia/history/`):

```julia
using ZedPlotPane

# Enable history tracking
enable_history!()

# Check history directory
println(history_dir())

# Disable history tracking
disable_history!()
```

## Persistent Configuration

Settings can be persisted across Julia sessions via `Preferences.jl`:

```julia
using ZedPlotPane

# Persistently set the cache directory
set_persistent_cache_dir!("~/my-project/plots")

# Persistently configure auto-init
set_persistent_auto_init!(false)

# Persistently enable plot history by default
set_persistent_history!(true)

# Persistently enable SVG to PNG rasterization
set_persistent_rasterize_svg!(true)
```

## SVG in-editor display (Rasterization fallback)

By default, SVG plots are wrapped in HTML and opened in your browser for full fidelity. If you prefer previewing SVG plots entirely inside Zed without external browser windows, you can enable SVG rasterization:

```julia
using ZedPlotPane

# Enable automatic SVG to PNG rasterization
enable_rasterize_svg!()
```

When enabled, `ZedPlotPane` attempts to rasterize SVGs to PNG using available system tools (`rsvg-convert`, ImageMagick `magick`/`convert`, or `inkscape`), or a custom rasterizer function:

```julia
# Optional: register a custom rasterizer function (e.g. using Rsvg.jl or Resvg.jl)
set_svg_rasterizer!((svg_path, png_path) -> begin
    # convert svg_path to png_path
    return true # return true on success
end)
```

If rasterization is unavailable or fails, it gracefully falls back to opening the HTML preview in the browser.





## Notes

- If the `zed` command is not available in your `PATH`, the package automatically searches for `/Applications/Zed.app/Contents/MacOS/cli` and falls back to using the macOS `open -a Zed` command.
- You can override or specify a custom Zed CLI path by setting the `ZED_CLI_PATH` environment variable.
- Zed extension-specific task/config files stay in `zed-julia`, not in this package.
