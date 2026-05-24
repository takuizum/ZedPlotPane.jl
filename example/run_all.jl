project_dir = @__DIR__
julia_cmd = Base.julia_cmd()

function run_demo(script_name::String, label::String)
    script_path = joinpath(project_dir, script_name)
    println("Running $label...")
    run(`$julia_cmd --project=$project_dir $script_path`)
end

run_demo("plots_gr_demo.jl", "Plots.jl (GR) demo")
run_demo("cairomakie_demo.jl", "CairoMakie demo")
run_demo("gadfly_demo.jl", "Gadfly demo")

println("Done.")
