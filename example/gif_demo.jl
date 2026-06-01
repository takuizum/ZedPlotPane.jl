using Plots
using ZedPlotPane

# Set up display and ensure environment variables are configured
ZedPlotPane.setup_display!()

# Create a simple animation
println("Generating animation frames...")
x = range(0, 2pi, length=100)
anim = @animate for i in 1:20
    plot(x, sin.(x .+ (0.2 * i)), title="Plots.jl GIF Frame #$i", lw=3, ylims=(-1.2, 1.2), legend=false)
end

# Save and display the animated GIF
println("Generating GIF and displaying...")
gif_obj = gif(anim, fps=10)
display(gif_obj)
println("Done.")
