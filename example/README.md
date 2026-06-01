# Examples for ZedPlotPane.jl

This directory contains demonstration scripts for various plotting backends.

## Running Examples

To run these examples, it is recommended to use the provided project environment:

1.  **Set up the environment**:
    From the project root, run:
    ```bash
    julia --project=example -e 'using Pkg; Pkg.develop("."); Pkg.instantiate()'
    ```

2.  **Run a demo**:
    ```bash
    julia --project=example example/plots_gr_demo.jl
    # or for matplotlib
    julia --project=example example/matplotlib_pythoncall_demo.jl
    ```

## Python Integration Note

If you are using `uv` or a custom virtual environment for Matplotlib/PythonCall, ensure your Julia `PythonCall` preferences are configured to point to your Python executable. 

Example using `PreferenceTools.jl`:
```julia
using PreferenceTools
PreferenceTools.add("CondaPkg", "backend" => "Null")
PreferenceTools.add("PythonCall", "exe" => "/path/to/your/venv/bin/python")
```
