MetadataTools.jl
================

Functionality to analyze the structure of Julia's METADATA repository.

[![Build Status](https://travis-ci.org/IainNZ/MetadataTools.jl.svg)](https://travis-ci.org/IainNZ/MetadataTools.jl)
[![Coverage Status](https://img.shields.io/coveralls/IainNZ/MetadataTools.jl.svg)](https://coveralls.io/r/IainNZ/MetadataTools.jl)

### Documentation

The code is the documentation, but here are the comments reproduced for your convenience.

```
get_pkg(meta_path::String, pkg_name::String)
  Return a structure with all information about the package listed in METADATA, e.g.
  julia> get_pkg("...", "DataFrames")
  DataFrames   git://github.com/JuliaStats/DataFrames.jl.git 
    0.0.0,a63047,Options,StatsBase
    0.1.0,7b1c6b,julia 0.1- 0.2-,Options,StatsBase
    0.2.0,b5f0fe,julia 0.2-,GZip,Options,StatsBase
    ...
    0.5.7,a8ae61,julia 0.3-,DataArrays,StatsBase 0.3.9+,GZip,Sort...
```

```
get_all_pkg(meta_path::String)
Walks through the METADATA folder, returns a vector of PkgMetas
for every package found.
```

```
get_upper_limit(pkg::PkgMeta)
Run through all versions of a package to try to determine if there
is an upper limit on the Julia version this package is installable
on. Does so by checking all Julia requirements across all versions.
If there is a limit, returns that version, otherwise v0.0.0
```
