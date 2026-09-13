# Examples for ZedPlotPane.jl

This directory contains demonstration scripts for various plotting backends.

## Running Examples

To run these examples, it is recommended to use the provided project environment:

1.  **Set up the environment**:
    From this directory (`example/`), run:
    ```bash
    julia --project
    ```
    Then inside Julia REPL:
    ```julia
    using Pkg
    Pkg.develop(path="..")  # Link the local ZedPlotPane library
    Pkg.instantiate()       # Install backends (Plots, PythonCall, etc.)
    ```

2.  **Run a demo**:
    ```julia
    include("plots_gr_demo.jl")
    # or for matplotlib
    include("matplotlib_pythoncall_demo.jl")
    ```

## Python Integration Note

If you are using `uv` or a custom virtual environment for Matplotlib/PythonCall, ensure your Julia `PythonCall` preferences are configured to point to your Python executable. 

Example using `PreferenceTools.jl`:
```julia
using PreferenceTools
PreferenceTools.add("CondaPkg", "backend" => "Null")
PreferenceTools.add("PythonCall", "exe" => "/path/to/your/venv/bin/python")
```
