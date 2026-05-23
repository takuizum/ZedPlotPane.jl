module ZedPlotPane

export ZedDisplay,
       auto_init_enabled,
       disable_auto_init!,
       enable_auto_init!,
       plot_path,
       setup_display!,
       register_display!,
       setup_environment!

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

struct ZedDisplay <: AbstractDisplay end
Base.displayable(::ZedDisplay, mime::MIME) = string(mime) in ("image/png", "image/jpeg", "text/html", "image/svg+xml")
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
end

function _write_image(path, x, mime::MIME)
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
            run(Cmd([cmd, path]); wait = false)
            return true
        catch
        end
    end

    # 2. System PATH lookup
    cmd = Sys.which("zed")
    if cmd !== nothing
        try
            run(Cmd([cmd, path]); wait = false)
            return true
        catch
        end
    end

    # 3. macOS specific lookups
    if Sys.isapple()
        mac_cli = "/Applications/Zed.app/Contents/MacOS/cli"
        if isfile(mac_cli)
            try
                run(Cmd([mac_cli, path]); wait = false)
                return true
            catch
            end
        end
        try
            run(Cmd(["open", "-a", "Zed", path]); wait = false)
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
        try run(Cmd(["open", path]); wait = false); return true; catch; end
    elseif Sys.iswindows()
        try run(Cmd(["cmd", "/c", "start", path]); wait = false); return true; catch; end
    elseif Sys.islinux()
        try run(Cmd(["xdg-open", path]); wait = false); return true; catch; end
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
    else
        return "png"
    end
end

function Base.display(::ZedDisplay, x)
    mimes = (
        MIME("image/png"),
        MIME("image/jpeg"),
        MIME("text/html"),
        MIME("image/svg+xml")
    )
    for mime in mimes
        if Base.invokelatest(showable, mime, x)
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
                printstyled("[Zed] SVG plot opened in browser via HTML wrapper: $(html_path)\n"; color = :cyan)
            elseif mime == MIME("text/html")
                _open_in_browser(path)
                printstyled("[Zed] dynamic plot opened in browser: $(path)\n"; color = :cyan)
            else
                if path != _LAST_OPENED_PATH[]
                    _LAST_OPENED_PATH[] = path
                    if _open_viewer(path)
                        printstyled("[Zed] plot pane opened - drag tab to a split for persistent side pane\n"; color = :cyan)
                    else
                        printstyled("[Zed] plot saved to $(path)\n"; color = :yellow)
                    end
                else
                    printstyled("[Zed] plot updated\n"; color = :cyan)
                end
            end
            return
        end
    end
    throw(MethodError(display, (ZedDisplay(), x)))
end

function _register_repush_callback!()
    _CALLBACK_REGISTERED[] && return
    push!(Base.package_callbacks, function(::Base.PkgId)
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
function setup_environment!()
    _ensure_plot_files()
    get!(ENV, "GKSwstype", "100")
    return nothing
end

function setup_display!(; register_callback::Bool = true)
    setup_environment!()
    register_display!()
    register_callback && _register_repush_callback!()
    return nothing
end

function __init__()
    !isinteractive() && return
    _AUTO_INIT[] || return
    setup_display!()
end

end # module
