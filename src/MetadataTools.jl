#######################################################################
# MetadataTools
# https://github.com/IainNZ/MetadataTools.jl
# (c) Iain Dunning 2014
# Licensed under the MIT License
#######################################################################

module MetadataTools

import Requests, JSON, Graphs

export get_pkg, get_all_pkg, get_upper_limit, get_pkg_info
export get_pkgs_dep_graph, get_pkg_dep_graph

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
Base.isequal(a::PkgMeta, b::PkgMeta) = (a.name == b.name && a.url == b.url)
(==)(a::PkgMeta, b::PkgMeta) = (a.name == b.name && a.url == b.url)

typealias PkgMetaDict Dict{String,PkgMeta}

function printer(io::IO, pmv::PkgMetaVersion)
    print(io, "  ", pmv.ver, ",", pmv.sha[1:6])
    map(r->print(io, ",",r), pmv.requires)
end
Base.print(io::IO, pmv::PkgMetaVersion) = printer(io,pmv)
Base.show(io::IO, pmv::PkgMetaVersion) = printer(io,pmv)

function printer(io::IO, pm::PkgMeta)
    println(io, pm.name, "   ", pm.url)
    for v in pm.versions[1:end-1]
        println(io, v)
    end
    if length(pm.versions) >= 1
        print(io, pm.versions[end])
    end
end
Base.print(io::IO, pm::PkgMeta) = printer(io,pm)
Base.show(io::IO, pm::PkgMeta) = printer(io,pm)

#######################################################################
# Contributor           A package contributor as defined by Github
# PkgInfo               Package info obtained from Github
immutable Contributor
    username::String
    url::String
end
immutable PkgInfo
    html_url::String  # URL of repo, in constrast to METADATA url
    description::String
    homepage::String
    stars::Int
    watchers::Int
    contributors::Vector{(Int,Contributor)}  # (commit_count,Contrib.)
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
# get_pkg_info
# Get information from Github (etc?) about a package.
function get_pkg_info(pkgs::PkgMetaDict; token=nothing)
    return [p[1] => get_pkg_info(p[2],token=token) for p in pkgs]
end
function get_pkg_info(pkg::PkgMeta; token=nothing)
    get_pkg_info(pkg.url, token=token)
end
function get_pkg_info(pkg_url::String; token=nothing)
    if contains(pkg_url, "github")
       return get_pkg_info_github(pkg_url::String, token=token)
    else
        error("get_pkg_info only supports packages hosted: GitHub.")
    end
end

# Helper function
function retry_get(url; max_attempts=3, sleep_time=0.5)
    failures = 0
    response = nothing
    while response == nothing
        try
            response = Requests.get(url).data
        catch
            failures += 1
            sleep(sleep_time)
        end
        if failures == max_attempts
            error("Failed to get data from $url 3 times!")
        end
    end
    return response
end

# Github version [not exported]
function get_pkg_info_github(pkg_url::String; token=nothing)
    println(pkg_url)
    # If a token is provided, use it
    token_arg = (token == nothing) ? "" : "?access_token=$(token)"

    # Extract owner/pkgname.jl from METADATA standardized URL, e.g.
    # git://github.com/owner/pkgname.jl.git
    url_split = split(pkg_url, "/")
    owner_pkg = url_split[end-1] * "/" * url_split[end][1:end-4]
    
    # Request 1 gets general information about package, containing:
    # description, homepage, stargazers_count, watchers_count        
    # API: GET /repos/:owner/:repo/
    # https://developer.github.com/v3/repos/#get
    sleep(0.5) # Avoid rate limiting?
    url = "https://api.github.com/repos/$(owner_pkg)$(token_arg)"
    req1 = JSON.parse(retry_get(url))
    # Deal with case where somehow the entry is there but
    # null, instead of just being absent.
    if get(req1, "html_url", nothing) == nothing
        req1["html_url"] = "No URL available."
    end
    if get(req1, "description", nothing) == nothing
        req1["description"] = "No desciption available."
    end
    if get(req1, "homepage", nothing) == nothing
        req1["homepage"] = "No homepage available."
    end


    # Request 2 gets contributor information, including their name,
    # website, and commit count
    # API: GET /repos/:owner/:repo/stats/contributors
    # https://developer.github.com/v3/repos/statistics/#contributors
    sleep(0.5) # Avoid rate limiting?
    url = "https://api.github.com/repos/$(owner_pkg)/stats/contributors$(token_arg)"
    req2 = JSON.parse(retry_get(url))
    if typeof(req2) <: Dict
        warn("$url returned error message: $req2")  # probably caused by move
        req2 = {}
    end

    # Request 3 gets the clone count, and isn't officially supported
    # by GitHub. Need to be logged in for it to work, so disabled until
    # a work around
    #https://github.com/JuliaOpt/JuMP.jl/graphs/clone-activity-data
    #=url = "https://github.com/$(owner_pkg)/graphs/clone-activity-data"
    println(url)
    println(Requests.get(url).headers)
    req3 = retry_get(url)
    println(req3)=#

    return PkgInfo(
        get(req1, "html_url", "No URL available."),
        get(req1, "description", "No desciption available."),
        get(req1, "homepage", "No homepage available."),
        get(req1, "stargazers_count", -1),
        get(req1, "subscribers_count", -1),
        (Int,Contributor)[(
            con["total"], 
            Contributor(con["author"]["login"],con["author"]["html_url"]))
            for con in req2]
        )
end

#######################################################################
# get_pkgs_dep_graph
# Given a vector of packages (i.e. the output of get_all_pkg) build
# a Graphs.jl directed graph, where there is an edge from PkgA to 
# PkgB iff PkgA directly requires PkgB. Alternatively, if reverse
# is true, reverse the direction of the arcs.
typealias PkgGraph Graphs.GenericGraph
function get_pkgs_dep_graph(pkgs::PkgMetaDict; reverse=false)
    g = Graphs.graph(collect(values(pkgs)), Graphs.Edge{PkgMeta}[], is_directed=true)
    
    for pkg in values(pkgs)
        if length(pkg.versions) == 0
            # This package doesn't have any tagged versions, so
            # we can't figure out anything about what it depends
            # on from METADATA alone.
            continue
        end
        # We use the most recent version - TODO could be to add
        # an option to modify this behaviour.
        pkgver = pkg.versions[end]
        for req in pkgver.requires
            if contains(req, "julia")
                # Julia version dependency, skip it
                continue
            end
            other_pkg = pkgs[(req[1] == '@') ? split(req," ")[2] : split(req," ")[1]]
            if reverse
                Graphs.add_edge!(g, other_pkg, pkg)
            else    
                Graphs.add_edge!(g, pkg, other_pkg)
            end
        end
    end

    return g
end

# get_pkg_dep_graph
# Get the dependency graph for a single package by running a BFS/DFS on
# the full dependency graph starting from the desired package
# We do this by creating a Graphs.jl visitor, then just passing that into
# the traversal algorithm
type SubgraphBuilderVisitor <: Graphs.AbstractGraphVisitor
    sub_graph::PkgGraph
    added::Dict{PkgMeta,Bool}
end
SubgraphBuilderVisitor() = SubgraphBuilderVisitor(
        Graphs.graph(PkgMeta[],Graphs.Edge{PkgMeta}[],is_directed=true),
        Dict{PkgMeta,Bool}())
function add_vert_no_dupe(visitor::SubgraphBuilderVisitor, v::PkgMeta)
    if !get(visitor.added, v, false)
        Graphs.add_vertex!(visitor.sub_graph, v)
        visitor.added[v] = true
    end
end
function Graphs.examine_neighbor!(visitor::SubgraphBuilderVisitor, u::PkgMeta, v::PkgMeta, vcolor::Int, ecolor::Int)
    add_vert_no_dupe(visitor, u)
    add_vert_no_dupe(visitor, v)
    Graphs.add_edge!(visitor.sub_graph, u, v)
end

get_pkg_dep_graph(pkg_name::String, pkgs::PkgMetaDict; reverse=false) =
    get_pkg_dep_graph(pkgs[pkg_name], pkgs, reverse=reverse)
get_pkg_dep_graph(pkg::PkgMeta, pkgs::PkgMetaDict; reverse=false) =
    get_pkg_dep_graph(pkg, get_pkgs_dep_graph(pkgs,reverse=reverse))
function get_pkg_dep_graph(pkg::PkgMeta, dep_graph::PkgGraph)
    v = SubgraphBuilderVisitor()
    Graphs.traverse_graph(dep_graph, Graphs.BreadthFirst(), pkg, v)
    return v.sub_graph
end

end  # module