using ZedPlotPane
using PythonCall

# Initialize ZedPlotPane display
ZedPlotPane.setup_display!()
ZedPlotPane.open_pane()

# Import matplotlib via PythonCall
plt = pyimport("matplotlib.pyplot")

# Data
x = 0:0.1:10
y = [sin(xi) for xi in x]

# Plotting
plt.figure(figsize=(8, 6))
plt.plot(x, y, label="sin(x)")
plt.title("Matplotlib with PythonCall in Zed")
plt.xlabel("x")
plt.ylabel("y")
plt.legend()
plt.grid(true)

# IMPORTANT: Call display() on the figure object to show it in Zed Plot Pane.
# PythonCall's Py objects for figures implement the necessary MIME types.
display(plt.gcf())

println("Plot should be displayed in Zed Plot Pane.")
