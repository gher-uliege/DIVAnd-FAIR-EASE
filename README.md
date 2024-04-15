![Commit](https://img.shields.io/github/last-commit/gher-uliege/DIVAnd-FAIR-EASE) ![GitHub top language](https://img.shields.io/github/languages/top/gher-uliege/DIVAnd-FAIR-EASE)

This repository stores the notebooks (`Jupyter` and `Pluto`) for the data download and `DIVAnd` analysis in the frame of the FAIR-EASE project.

## Installation

* Julia: 
```bash
curl -fsSL https://install.julialang.org | sh
```

## Run the code

In a Julia session:
```julia
using Pkg; Pkg.add("Pluto")
using Pluto
Pluto.run()
```
This command should issue a message such as:
```
[ Info: Loading...
┌ Info: 
└ Opening http://localhost:1234/?secret=sBT5gG12 in your default browser... ~ have fun!
┌ Info: 
│ Press Ctrl+C in this terminal to stop Pluto
└ 
```
and the notebook interface got open in your browser.    

Select the file called `get_argo_data_pluto.jl`.
