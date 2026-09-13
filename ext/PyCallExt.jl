module PyCallExt

using ZedPlotPane
using PyCall

function __init__()
    ZedPlotPane._FIX_MPL_BACKEND_CALLBACK[] = function ()
        try
            PyCall.pyimport("matplotlib")[:use]("Agg")
        catch
        end
    end
end

end # module
