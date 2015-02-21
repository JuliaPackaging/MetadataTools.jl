MetadataTools.jl
================

Functionality to analyze the structure of Julia's METADATA repository.

[![Build Status](https://travis-ci.org/IainNZ/MetadataTools.jl.svg)](https://travis-ci.org/IainNZ/MetadataTools.jl)
[![Coverage Status](https://img.shields.io/coveralls/IainNZ/MetadataTools.jl.svg)](https://coveralls.io/r/IainNZ/MetadataTools.jl)

**Installation**: `Pkg.add("MetadataTools")`

## Documentation

... is pretty much just the comments in the code. I also gave a talk about MetadataTools.jl and I've posted the [associated IJulia Notebook](http://iaindunning.com/2014/metadatatools.html). Here are the code comments reproduced for your convenience:

#### `get_pkg(pkg_name::String; meta_path::String=Pkg.dir("METADATA"))`

Return a structure with all information about the package listed in METADATA, e.g.
```
  julia> get_pkg("DataFrames")
  DataFrames   git://github.com/JuliaStats/DataFrames.jl.git 
    0.0.0,a63047,Options,StatsBase
    0.1.0,7b1c6b,julia 0.1- 0.2-,Options,StatsBase
    0.2.0,b5f0fe,julia 0.2-,GZip,Options,StatsBase
    ...
    0.5.7,a8ae61,julia 0.3-,DataArrays,StatsBase 0.3.9+,GZip,Sort...
```

#### `get_all_pkg(; meta_path::String=Pkg.dir("METADATA"))`
Walks through the METADATA folder, returns a vector of `PkgMeta`s
for every package found.


#### `get_upper_limit(pkg::PkgMeta)`
Run through all versions of a package to try to determine if there
is an upper limit on the Julia version this package is installable
on. Does so by checking all Julia requirements across all versions.
If there is a limit, returns that version, otherwise `v0.0.0`


#### `get_pkg_info(pkg::PkgMeta; token=nothing)`
#### `get_pkg_info(pkg_url::String; token=nothing)`
Populates the following type as much as possible using information
from package hosting (currently only GitHub). Can take an auth
token if available. `pkg_url` should be a METADATA.jl style url, 
i.e. ``git://...``

```julia
immutable PkgInfo
    html_url::String  # URL of repo, in constrast to METADATA url
    description::String
    homepage::String
    stars::Int
    watchers::Int
    contributors::Vector{(Int,Contributor)}  # (commit_count,Contrib.)
end
immutable Contributor
    username::String
    url::String
end
```
