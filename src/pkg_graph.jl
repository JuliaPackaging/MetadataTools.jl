#-----------------------------------------------------------------------
# MetadataTools
# https://github.com/IainNZ/MetadataTools.jl
#-----------------------------------------------------------------------
# Copyright (c) 2015: Iain Dunning
# Licensed under the MIT License
#-----------------------------------------------------------------------
# src/pkg_graph.jl
# Converts METADATA to a graph and provides some operations on that
# graph such as extracting [reverse] dependency graphs for a package.
#----------------------------------------------------------------------

export make_dep_graph, get_pkg_dep_graph

"""
    PkgGraph

A lightweight wrapper around a LightGraphs.jl representation of a
package dependency graph.
"""
mutable struct PkgGraph
    adjlist::Vector{Vector{Int}}
    pkgnames::Vector{String}
    pkgname_idx::Dict{String,Int}
end

"""
    size(pg::PkgGraph)

Returns the number of packages in a package dependency graph.
"""
Base.size(pg::PkgGraph) = length(pg.adjlist)

"""
    packages(pg::PkgGraph)

Returns the names of the packages in a package dependency graph
as a vector.
"""
packages(pg::PkgGraph) = copy(pkgnames)

"""
    adjlist(pkg::PkgGraph)

Returns a representation of a package dependency graph as a simple
adjacency list, using integer indices
"""
adjlist(pg::PkgGraph) = pg.adjlist

"""
    make_dep_graph(pkgs::Dict{UTF8String,PkgMeta}; reverse=false)

Given a Dict{UTF8String,PkgMeta} (e.g., from `get_all_pkg`), build a
directed graph with an edge from PkgA to PkgB iff PkgA directly requires
PkgB. Alternatively reverse the direction of the edges if `reverse` is true.
"""
function make_dep_graph(pkgs::Dict{String,PkgMeta}; reverse=false)
    pkgnames = collect(keys(pkgs))
    pkgname_idx = Dict{String,Int}(pkgname => i for (i, pkgname) in enumerate(pkgnames))
    numpkg   = length(pkgnames)
    adjlist  = Vector{Int}[Vector{Int}() for pkgname in pkgnames]

    # Build up the edges of the graph
    for (pkg_name, pkg_meta) in pkgs
        if length(pkg_meta.versions) == 0
            # This package doesn't have any tagged versions, so
            # we can't figure out anything about what it depends
            # on from METADATA alone. Give up.
            continue
        end
        # We use the most recent version
        # TODO: add an option to modify this behaviour.
        pkg_ver = pkg_meta.versions[end]
        for req in pkg_ver.requires  # Requirements are plain strings
            if contains(req, "julia")
                # Julia version dependency, skip it
                continue
            end
            # Strip OS-specific conditions
            other_pkg = (req[1] == '@') ? split(req," ")[2] : split(req," ")[1]
            # Special case the the cycle:
            # LibCURL -> WinRPM (on Windows only)
            # WinRPM -> HTTPClient (on Unix only)
            # HTTPClient -> LibCurl
            # by breaking WinRPM -> HTTPClient
            if pkg_name == "WinRPM" && other_pkg == "HTTPClient"
                continue
            end
            # Map names to indices
            src, dst = pkgname_idx[pkg_name], pkgname_idx[other_pkg]
            # Add the directed edge
            if reverse
                dst, src = src, dst
            end
            if dst ∉ adjlist[src]
                push!(adjlist[src], dst)
            end
        end
    end

    return PkgGraph(adjlist, pkgnames, pkgname_idx)
end

"""
    get_pkg_dep_graph(pkg::PkgMeta, pg::PkgGraph; depth=Inf)
    get_pkg_dep_graph(pkgname::AbstractString, pg::PkgGraph; depth=Inf)

Returns a subgraph of the package dependency graph starting at a given
package. Optional keyword argument controls depth - depth=2 is just the
immediate dependencies.
"""
function get_pkg_dep_graph(pkg::PkgMeta, pg::PkgGraph; depth=Inf)
    get_pkg_dep_graph(pkg.name, pg, depth=depth)
end
function get_pkg_dep_graph(pkgname::AbstractString, pg::PkgGraph; depth=Inf)
    # Run a DFS to find the connected component
    # While doing so, building a mapping from old indices to
    # new indices in the subgraph
    n = size(pg)
    visited = zeros(Bool, n)
    stack = Int[pg.pkgname_idx[pkgname]]
    depth_stack = Int[1]
    old_idx_to_new_idx = Dict{Int,Int}()
    new_n = 0
    while length(stack) > 0
        cur_idx = pop!(stack)
        cur_depth = pop!(depth_stack)
        visited[cur_idx] && continue
        cur_depth > depth && continue
        visited[cur_idx] = true
        new_n += 1
        old_idx_to_new_idx[cur_idx] = new_n
        for dep_idx in pg.adjlist[cur_idx]
            if !visited[dep_idx]
                push!(stack, dep_idx)
                push!(depth_stack, cur_depth + 1)
            end
        end
    end
    # Build subgraph
    new_pkgnames = String["" for i in 1:new_n]
    new_pkgname_idx = Dict{String,Int}()
    new_adjlist  = Vector{Int}[Vector{Int}() for i in 1:new_n]
    for old_idx in 1:n
        !visited[old_idx] && continue
        new_idx = old_idx_to_new_idx[old_idx]
        new_pkgnames[new_idx] = pg.pkgnames[old_idx]
        new_pkgname_idx[pg.pkgnames[old_idx]] = new_idx
        for old_dep_idx in pg.adjlist[old_idx]
            if visited[old_dep_idx]  # might not have due to depth
                new_dep_idx = old_idx_to_new_idx[old_dep_idx]
                push!(new_adjlist[new_idx], new_dep_idx)
            end
        end
    end
    return PkgGraph(new_adjlist, new_pkgnames, new_pkgname_idx)
end
