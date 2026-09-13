module PythonCallExt

using ZedPlotPane
using PythonCall

function __init__()
    ZedPlotPane._FIX_MPL_BACKEND_CALLBACK[] = function ()
        try
            PythonCall.pyimport("matplotlib").use("Agg")
        catch
        end
    end
end

end # module
