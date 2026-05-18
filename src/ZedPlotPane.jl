module ZedPlotPane

export ZedDisplay,
       auto_init_enabled,
       disable_auto_init!,
       enable_auto_init!,
       plot_path,
       setup_display!

const PLOT_PATH = expanduser("~/.cache/zed-julia/current-plot.png")

const BLANK_PNG = UInt8[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]

struct ZedDisplay <: AbstractDisplay end
const _PLOT_OPENED = Ref(false)
const _AUTO_INIT = Ref(true)
const _CALLBACK_REGISTERED = Ref(false)

plot_path() = PLOT_PATH
auto_init_enabled() = _AUTO_INIT[]
enable_auto_init!() = (_AUTO_INIT[] = true)
disable_auto_init!() = (_AUTO_INIT[] = false)

function _ensure_plot_file()
    dir = dirname(PLOT_PATH)
    isdir(dir) || mkpath(dir)
    isfile(PLOT_PATH) || write(PLOT_PATH, BLANK_PNG)
end

function _write_image(x, mime::MIME)
    open(PLOT_PATH, "w") do io
        Base.invokelatest(show, io, mime, x)
    end
end

function _open_viewer()
    cmd = Sys.which("zed")
    cmd === nothing && return false
    try
        run(Cmd([cmd, PLOT_PATH]); wait = false)
        return true
    catch
        return false
    end
end

function Base.display(::ZedDisplay, x)
    for mime in (MIME("image/png"), MIME("image/svg+xml"))
        if Base.invokelatest(showable, mime, x)
            _write_image(x, mime)
            if !_PLOT_OPENED[]
                _PLOT_OPENED[] = true
                if _open_viewer()
                    printstyled("[Zed] plot pane opened - drag tab to a split for persistent side pane\n"; color = :cyan)
                else
                    printstyled("[Zed] plot saved to $(PLOT_PATH)\n"; color = :yellow)
                end
            else
                printstyled("[Zed] plot updated\n"; color = :cyan)
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

function setup_display!(; register_callback::Bool = true)
    _ensure_plot_file()
    get!(ENV, "GKSwstype", "100")
    _ensure_display_priority!()
    register_callback && _register_repush_callback!()
    return nothing
end

function __init__()
    !isinteractive() && return
    _AUTO_INIT[] || return
    setup_display!()
end

end # module
