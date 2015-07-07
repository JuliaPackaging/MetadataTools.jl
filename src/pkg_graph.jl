#----------------------------------------------------------------------
# MetadataTools
# https://github.com/IainNZ/MetadataTools.jl
# (c) Iain Dunning 2015
# Licensed under the MIT License
#----------------------------------------------------------------------
# pkg_graph.jl
# Converts METADATA to a graph and provides some operations on that
# graph such as extracting [reverse] dependency graphs for a package.
#----------------------------------------------------------------------
export make_dep_graph, get_pkg_dep_graph

using LightGraphs

type PkgGraph
    g::DiGraph
    num_p::Int    # True number of packages, possibly != nv(g)
    p_to_i::Dict  # Package names to an internal index
    i_to_p::Dict  # Internal index to package name
end

# numpackages
# PkgGraph -> Int
# Get number of packages in graph
numpackages(pg::PkgGraph) = pg.num_p

# packagenames
# PkgGraph -> Vector{String}
# Extract the vector of package names from the graph
packages(pg::PkgGraph) = [pg.i_to_p[k] for k in 1:pg.num_p]

# adjlist
# PkgGraph -> Vector{Vector{Int}}
# Convert the graph to adjacency list format
function adjlist(pg::PkgGraph)
    adj = Vector{Int}[]
    for i in 1:pg.num_p
        push!(adj, collect(out_neighbors(pg.g, i)))
    end
    return adj
end

# make_dep_graph
# PkgMetaDict -> PkgGraph
# Given a PkgMetaDict, build a directed graph with an edge from PkgA
# to PkgB iff PkgA directly requires PkgB. Alternatively, if reverse
# is true, reverse the direction of the edges.
function make_dep_graph(pkgs::PkgMetaDict; reverse=false)
    # LightGraphs.jl operates with integer indicies, so assign each
    # package name to an integer and vice versa
    num_pkgs = 0
    p_to_i = Dict()
    i_to_p = Dict()
    for pkg_name in keys(pkgs)
        num_pkgs += 1
        p_to_i[pkg_name] = num_pkgs
        i_to_p[num_pkgs] = pkg_name
    end

    # Initialize graph with one vertex for each package
    g = DiGraph(num_pkgs)
    
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
            src, dst = p_to_i[other_pkg], p_to_i[pkg_name]
            if reverse
                !has_edge(g,src,dst) && add_edge!(g,src,dst)
            else    
                !has_edge(g,dst,src) && add_edge!(g,dst,src)
            end
        end
    end

    # Break the cycle
    libcurl = p_to_i["LibCURL"]
    winrpm  = p_to_i["WinRPM"]
    if reverse
        rem_edge!(g,winrpm,libcurl)
    else
        rem_edge!(g,libcurl,winrpm)
    end

    return PkgGraph(g, nv(g), p_to_i, i_to_p)
end

# get_pkg_dep_graph
# (String, PkgGraph) -> PkgGraph
# (PkgMeta, PkgGraph) -> PkgGraph
# Get the dep. graph for a single package by running a traversal on
# the full dep. graph starting from the desired package. Uses a
# LightGraphs.jl visitor, we pass that into the traversal algorithm
type SubgraphVisitor <: LightGraphs.SimpleGraphVisitor
    old_depgraph
    num_v
    old_i_to_new_i
    new_graph
    cyclewarn
end
SubgraphVisitor(depgraph,cyclewarn) =
    SubgraphVisitor(depgraph, 0, Dict(), DiGraph(depgraph.num_p), cyclewarn)

function LightGraphs.discover_vertex!(vis::SubgraphVisitor, v)
    # Give vertex v a new index, if it doesn't have one yet
    if v ∉ keys(vis.old_i_to_new_i)
        vis.num_v += 1
        vis.old_i_to_new_i[v] = vis.num_v
    end
    true
end
function LightGraphs.examine_neighbor!(vis::SubgraphVisitor,
                                        u, v,
                                        vcolor::Int, ecolor::Int)
    # Make sure we have indices for the neighbour
    if v ∉ keys(vis.old_i_to_new_i)
        vis.num_v += 1
        vis.old_i_to_new_i[v] = vis.num_v
    end
    # Add the edge to the visitor's graph
    src, dst = vis.old_i_to_new_i[u], vis.old_i_to_new_i[v]
    if !has_edge(vis.new_graph, src, dst)
        add_edge!(vis.new_graph, src, dst)
    end
end

get_pkg_dep_graph(pkg::PkgMeta, depgraph::PkgGraph) = get_pkg_dep_graph(pkg.name, depgraph)
function get_pkg_dep_graph(pkgname::String, depgraph::PkgGraph; cyclewarn=true)
    # Construct the vistor
    vis = SubgraphVisitor(depgraph,cyclewarn)
    # Walk the graph starting from the package in question
    traverse_graph(depgraph.g, LightGraphs.DepthFirst(),
                    depgraph.p_to_i[pkgname], vis)
    # The new graph will have vertices in a new index scheme
    p_to_i, i_to_p = Dict(), Dict()
    for (p, i) in depgraph.p_to_i
        if i in keys(vis.old_i_to_new_i)
            # This vertex is in the final graph
            i_new = vis.old_i_to_new_i[i]
            p_to_i[p] = i_new
            i_to_p[i_new] = p
        end
    end
    return PkgGraph(vis.new_graph, length(i_to_p), p_to_i, i_to_p)
end