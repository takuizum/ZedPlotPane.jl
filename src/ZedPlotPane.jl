module ZedPlotPane

export ZedDisplay,
    auto_init_enabled,
    disable_auto_init!,
    enable_auto_init!,
    plot_path,
    setup_display!,
    register_display!,
    setup_environment!,
    open_pane

const CACHE_DIR = expanduser("~/.cache/zed-julia")

const BLANK_PNG = UInt8[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]

const BLANK_SVG = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1\" height=\"1\"></svg>"

const BLANK_HTML = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"></head><body></body></html>"

const BLANK_GIF = UInt8[
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00,
    0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0x21, 0xf9, 0x04, 0x01, 0x00,
    0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
    0x00, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3b
]

struct ZedDisplay <: AbstractDisplay end
Base.displayable(::ZedDisplay, mime::MIME) = string(mime) in ("image/png", "image/jpeg", "image/gif", "text/html", "image/svg+xml")
const _LAST_OPENED_PATH = Ref{String}("")
const _AUTO_INIT = Ref(true)
const _CALLBACK_REGISTERED = Ref(false)

plot_path() = joinpath(CACHE_DIR, "current-plot.png")
plot_path(ext::AbstractString) = joinpath(CACHE_DIR, "current-plot.$ext")

auto_init_enabled() = _AUTO_INIT[]
enable_auto_init!() = (_AUTO_INIT[] = true)
disable_auto_init!() = (_AUTO_INIT[] = false)

function _ensure_plot_files()
    isdir(CACHE_DIR) || mkpath(CACHE_DIR)
    isfile(plot_path("png")) || write(plot_path("png"), BLANK_PNG)
    isfile(plot_path("svg")) || write(plot_path("svg"), BLANK_SVG)
    isfile(plot_path("html")) || write(plot_path("html"), BLANK_HTML)
    isfile(plot_path("gif")) || write(plot_path("gif"), BLANK_GIF)
end

function _write_image(path, x, mime::MIME)
    if hasfield(typeof(x), :filename)
        try
            if abspath(x.filename) == abspath(path)
                return
            end
        catch
        end
    end
    open(path, "w") do io
        Base.invokelatest(show, io, mime, x)
    end
end

function _open_viewer(path)
    get(ENV, "ZED_PLOT_PANE_TESTING", "false") == "true" && return true

    # 1. Custom ENV path
    cmd = get(ENV, "ZED_CLI_PATH", nothing)
    if cmd !== nothing
        try
            run(Cmd([cmd, path]); wait=false)
            return true
        catch
        end
    end

    # 2. System PATH lookup
    cmd = Sys.which("zed")
    if cmd !== nothing
        try
            run(Cmd([cmd, path]); wait=false)
            return true
        catch
        end
    end

    # 3. macOS specific lookups
    if Sys.isapple()
        mac_cli = "/Applications/Zed.app/Contents/MacOS/cli"
        if isfile(mac_cli)
            try
                run(Cmd([mac_cli, path]); wait=false)
                return true
            catch
            end
        end
        try
            run(Cmd(["open", "-a", "Zed", path]); wait=false)
            return true
        catch
        end
    end

    return false
end

function _open_viewer()
    _open_viewer(plot_path("png"))
end

function _open_in_browser(path)
    get(ENV, "ZED_PLOT_PANE_TESTING", "false") == "true" && return true

    if Sys.isapple()
        try
            run(Cmd(["open", path]); wait=false)
            return true
        catch
        end
    elseif Sys.iswindows()
        try
            run(Cmd(["cmd", "/c", "start", path]); wait=false)
            return true
        catch
        end
    elseif Sys.islinux()
        try
            run(Cmd(["xdg-open", path]); wait=false)
            return true
        catch
        end
    end
    return false
end

function mime_to_ext(mime::MIME)
    mstr = string(mime)
    if mstr == "text/html"
        return "html"
    elseif mstr == "image/svg+xml"
        return "svg"
    elseif mstr == "image/png"
        return "png"
    elseif mstr == "image/jpeg"
        return "jpg"
    elseif mstr == "image/gif"
        return "gif"
    else
        return "png"
    end
end

"""
    _is_interactive_html(html) -> Bool

Heuristic to decide whether a `text/html` representation is an interactive web
plot (Plotly, Bokeh, VegaLite/Altair, WGLMakie, folium, ...) that should be
opened in the browser, versus static markup such as a `pandas`/`polars`/
`DataFrames` table, `Base.Docs.HTML`, or rendered Markdown that should fall
through to the REPL's `text/plain` rendering.

Interactive plots embed JavaScript (`<script>`) or wrap their content in an
`<iframe>` (e.g. folium escapes its `<script>` inside an iframe `srcdoc`),
whereas static tables are pure markup. Keying on those two markers cleanly
separates the two without enumerating every plotting library.
"""
_is_interactive_html(html::AbstractString) = occursin(r"<script|<iframe"i, html)

function Base.display(::ZedDisplay, x)
    mimes = (
        MIME("image/png"),
        MIME("image/jpeg"),
        MIME("image/gif"),
        MIME("text/html"),
        MIME("image/svg+xml")
    )
    for mime in mimes
        Base.invokelatest(showable, mime, x) || continue

        # text/html is ambiguous: interactive plots and plain tables (pandas,
        # polars, DataFrames, Base.Docs.HTML, ...) are both showable as HTML.
        # Only open the browser for interactive plots; otherwise skip this MIME
        # so the value falls through to the REPL's text/plain rendering instead
        # of spuriously launching a browser window.
        if mime == MIME("text/html")
            html = sprint(io -> Base.invokelatest(show, io, mime, x))
            _is_interactive_html(html) || continue
            path = plot_path("html")
            write(path, html)
            _open_in_browser(path)
            printstyled("[Zed] dynamic plot opened in browser: $(path)\n"; color=:cyan)
            return
        end

        ext = mime_to_ext(mime)
        path = plot_path(ext)
        _write_image(path, x, mime)

        if mime == MIME("image/svg+xml")
            svg_content = read(path, String)
            html_wrapper = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <title>Zed Plot SVG Preview</title>
                <style>
                    body {
                        margin: 0;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        height: 100vh;
                        background-color: #1e1e24;
                    }
                    svg {
                        max-width: 95vw;
                        max-height: 95vh;
                    }
                </style>
            </head>
            <body>
                $(svg_content)
            </body>
            </html>
            """
            html_path = plot_path("html")
            write(html_path, html_wrapper)
            _open_in_browser(html_path)
            printstyled("[Zed] SVG plot opened in browser via HTML wrapper: $(html_path)\n"; color=:cyan)
        else
            if path != _LAST_OPENED_PATH[]
                _LAST_OPENED_PATH[] = path
                if _open_viewer(path)
                    printstyled("[Zed] plot pane opened - drag tab to a split for persistent side pane\n"; color=:cyan)
                else
                    printstyled("[Zed] plot saved to $(path)\n"; color=:yellow)
                end
            else
                printstyled("[Zed] plot updated\n"; color=:cyan)
            end
        end
        return
    end
    throw(MethodError(display, (ZedDisplay(), x)))
end

function _register_repush_callback!()
    _CALLBACK_REGISTERED[] && return
    push!(Base.package_callbacks, function (::Base.PkgId)
        _ensure_display_priority!()
    end)
    _CALLBACK_REGISTERED[] = true
end

function _ensure_display_priority!()
    displays = Base.Multimedia.displays
    indices = findall(d -> d isa ZedDisplay, displays)
    if isempty(indices)
        pushdisplay(ZedDisplay())
        return
    end

    keep_idx = indices[1]
    for idx in reverse(indices[2:end])
        splice!(displays, idx)
    end

    keep_idx = findfirst(d -> d isa ZedDisplay, displays)
    keep_idx === nothing && return
    keep_idx == length(displays) && return
    push!(displays, splice!(displays, keep_idx))
end

"""
    register_display!()

Register `ZedDisplay` as a Julia display at the top of the display stack.
"""
function register_display!()
    _ensure_display_priority!()
    return nothing
end

"""
    setup_environment!()

Configure environment variables (e.g., set GKSwstype to "100" for headless plotting)
and ensure the cache directory exists.
"""
const _FIX_MPL_BACKEND_CALLBACK = Ref{Function}(() -> nothing)

function setup_environment!()
    _ensure_plot_files()
    # Force headless backends for Zed
    ENV["GKSwstype"] = "100"
    ENV["MPLBACKEND"] = "Agg"
    _FIX_MPL_BACKEND_CALLBACK[]()
    return nothing
end

function setup_display!(; register_callback::Bool=true)
    setup_environment!()
    register_display!()
    register_callback && _register_repush_callback!()
    return nothing
end

"""
    open_pane()

Manually open the Zed plot pane. This is useful if the pane was closed
and you want to re-open it without waiting for the next plot command.
"""
function open_pane()
    _ensure_plot_files()
    if _open_viewer()
        _LAST_OPENED_PATH[] = plot_path("png")
        printstyled("[Zed] plot pane opened\n"; color=:cyan)
    else
        printstyled("[Zed] could not open viewer (is 'zed' in your PATH?)\n"; color=:red)
    end
    return nothing
end

function __init__()
    !isinteractive() && return
    _AUTO_INIT[] || return
    setup_display!()
end

end # module
