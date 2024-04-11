A Julia project comes with 2 files

* Project.toml: describes the project on a high level
* Manifest.toml: absolute record of the state of the packages in the environment

[deps] section: dependencies of the package/project, with the package name and its uuid
[compat] section: details the possible compatibility constraints
(https://pkgdocs.julialang.org/v1/toml-files/)

The two files are appended to the Pluto notebook, ensure that the very same environment is used.