![Commit](https://img.shields.io/github/last-commit/gher-uliege/DIVAnd-FAIR-EASE) ![GitHub top language](https://img.shields.io/github/languages/top/gher-uliege/DIVAnd-FAIR-EASE)

This repository stores the notebooks (`Jupyter` and `Pluto`) for the data download with [`Beacon`](https://beacon-argo.maris.nl/swagger/) and the gridding with [`DIVAnd`](https://github.com/gher-uliege/DIVAnd.jl) in the frame of the [FAIR-EASE](https://fairease.eu/) project.

## Installation

### Julia

Instructions from https://julialang.org/downloads/

- Linux and MacOS
```bash
curl -fsSL https://install.julialang.org | sh
```

- Windows
```bash
winget install julia -s msstore
```

### Pluto 

Select one of the two following methods:

- Using the package REPL (pressing the `]` key at the Julian REPL prompt) or 
```julia
(@v1.10) pkg> add Pluto
```
- Using the Pkg module:
```julia
julia> using Pkg.add("Pluto")
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
