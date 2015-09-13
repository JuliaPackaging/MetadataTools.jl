#######################################################################
# MetadataTools
# https://github.com/IainNZ/MetadataTools.jl
# (c) Iain Dunning 2015
# Licensed under the MIT License
#######################################################################

module MetadataTools

import Requests, JSON
import Base: ==, isequal, print, show
using Compat

export get_pkg, get_all_pkg, get_upper_limit, get_pkg_info

#######################################################################
# PkgMeta           Represents a packages entry in METADATA.jl
# PkgMetaVersion    Represents a version of a package in METADATA.jl
immutable PkgMetaVersion
    ver::VersionNumber
    sha::String
    requires::Vector{String}
end
immutable PkgMeta
    name::String
    url::String
    versions::Vector{PkgMetaVersion}
end
isequal(a::PkgMeta, b::PkgMeta) = (a.name == b.name && a.url == b.url)
(==)(a::PkgMeta, b::PkgMeta) = isequal(a,b)

typealias PkgMetaDict Dict{String,PkgMeta}

function printer(io::IO, pmv::PkgMetaVersion)
    print(io, "  ", pmv.ver, ",", pmv.sha[1:6])
    map(r->print(io, ",",r), pmv.requires)
end

function printer(io::IO, pm::PkgMeta)
    println(io, pm.name, "   ", pm.url)
    for v in pm.versions[1:end-1]
        println(io, v)
    end
    if length(pm.versions) >= 1
        print(io, pm.versions[end])
    end
end
print(io::IO, pm::Union{PkgMeta, PkgMetaVersion}) = printer(io, pm)
show(io::IO, pm::Union{PkgMeta, PkgMetaVersion}) = printer(io, pm)


#######################################################################
# Contributor           A package contributor as defined by Github
# PkgInfo               Package info obtained from Github
immutable Contributor
    username::String
    url::String
end
immutable PkgInfo
    html_url::String  # URL of repo, in contrast to METADATA url
    description::String
    homepage::String
    stars::Int
    watchers::Int
    contributors::Vector{@compat Tuple{Int,Contributor}}  # (commit_count,Contrib.)
end


#######################################################################
# get_pkg 
#   Return a PkgMeta with all information about the package listed
#   in METADATA, e.g.
#
#   julia> get_pkg("DataFrames")
#   DataFrames   git://github.com/JuliaStats/DataFrames.jl.git
#     0.0.0,a63047,Options,StatsBase
#     0.1.0,7b1c6b,julia 0.1- 0.2-,Options,StatsBase
#     0.2.0,b5f0fe,julia 0.2-,GZip,Options,StatsBase
#     ...
#     0.5.7,a8ae61,julia 0.3-,DataArrays,StatsBase 0.3.9+,GZip,Sort...
#
function get_pkg(pkg_name::String; meta_path::String=Pkg.dir("METADATA"))
    !isdir(meta_path) && error("Couldn't find METADATA folder at $meta_path")

    pkg_path = joinpath(meta_path,pkg_name)
    !isdir(pkg_path) && error("Couldn't find $pkg_name at $pkg_path")
    
    url_path = joinpath(pkg_path,"url")
    !isfile(url_path) && error("Couldn't find url for $pkg_name (expected $url_path)")
    url = chomp(readall(url_path))

    vers_path = joinpath(pkg_path,"versions")
    !isdir(vers_path) &&
        # No versions tagged
        return PkgMeta(pkg_name, url, PkgMetaVersion[])
    
    vers = PkgMetaVersion[]
    for dir in readdir(vers_path)
        ver_num = convert(VersionNumber, dir)
        ver_path = joinpath(vers_path, dir)
        sha = strip(readall(joinpath(ver_path,"sha1")))
        req_path = joinpath(ver_path,"requires")
        reqs = String[]
        if isfile(req_path)
            req_file = map(strip,split(readall(req_path),"\n"))
            for req in req_file
                length(req) == 0 && continue
                req[1] == '#' && continue
                push!(reqs, req)
            end
        end
        push!(vers,PkgMetaVersion(ver_num,sha,reqs))
    end
    # Sort ascending by version number
    sort!(vers, by=(v->v.ver))
    return PkgMeta(pkg_name, url, vers)
end


#######################################################################
# get_all_pkg
# Returns a dictionary of [package_name => PkgMeta] for every package
# in a METADATA folder.
function get_all_pkg(; meta_path::String=Pkg.dir("METADATA"))
    !isdir(meta_path) && error("Couldn't find METADATA folder at $meta_path")
    
    pkgs = Dict{String,PkgMeta}()
    for fname in readdir(meta_path)
        # Skip files
        !isdir(joinpath(meta_path, fname)) && continue
        # Skip "hidden" folders like .test
        (fname[1] == '.') && continue
        # Get the package and shove it in the dictionary
        pkgs[fname] = get_pkg(fname, meta_path=meta_path)
    end

    return pkgs
end


#######################################################################
# get_upper_limit
# Run through all versions of a package to try to determine if there
# is an upper limit on the Julia version this package is installable
# on. Does so by checking all Julia requirements across all versions.
# If there is a limit, returns that version, otherwise v0.0.0
function get_upper_limit(pkg::PkgMeta)
    upper = v"0.0.0"
    all_max = true
    for ver in pkg.versions
        julia_max_ver = v"0.0.0"
        # Check if there is a Julia max version dependency
        for req in ver.requires
            !contains(req,"julia") && continue
            s = split(req," ")
            length(s) != 3 && continue
            julia_max_ver = convert(VersionNumber,s[3])
            break
        end
        # If there wasn't, then at least one version will work on
        # any Julia, so stop looking
        if julia_max_ver == v"0.0.0"
            all_max = false
            break
        else
            # Only record the highest max version
            if julia_max_ver > upper
                upper = julia_max_ver
            end
        end
    end
    return all_max ? upper : v"0.0.0"
end

#######################################################################
# Functionality to get information about a package, currently all
# from Github but other providers could be supported.
include("pkg_info.jl")

#######################################################################
# Functionality for operations on the package dependency graph
include("pkg_graph.jl")

end  # module
