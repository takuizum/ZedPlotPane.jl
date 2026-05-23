import Pkg

Pkg.activate(@__DIR__)
Pkg.develop(path=normpath(joinpath(@__DIR__, "..")))
Pkg.instantiate()
Pkg.precompile()

println("example environment is ready.")
