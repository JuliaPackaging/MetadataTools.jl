#######################################################################
# MetadataTools
# https://github.com/IainNZ/MetadataTools.jl
# (c) Iain Dunning 2014
# Licensed under the MIT License
#######################################################################
# graph_stats.jl
# Calculate some rankings for package connectedness
#######################################################################

using MetadataTools
using Graphs

# Load in all the package data from METADATA
pkgs = get_all_pkg()

# Build a graph with edges A->B if A directly requires B
g = get_pkgs_dep_graph(pkgs)
# Count size of every connected subgraph obtained by traversing the
# dependency graph starting from each package
num_pkg_req = [
    (num_vertices(get_pkg_dep_graph(pkg, g)), pkg.name)
        for pkg in values(pkgs)]
sort!(num_pkg_req, rev=true)  # Sort descending
println("Top 10 packages by number of packages depended on:")
for i in 1:10
    println(rpad(num_pkg_req[i][2],20," "), num_pkg_req[i][1]-1)
end

# Build a graph with edges A->B if A is directly required by B
g = get_pkgs_dep_graph(pkgs, reverse=true)
# Count size of every subgraphs like above
num_pkg_req = [
    (num_vertices(get_pkg_dep_graph(pkg, g)), pkg.name)
        for pkg in values(pkgs)]
sort!(num_pkg_req, rev=true)  # Sort descending
println("Top 10 packages by number of packages that depend on them:")
for i in 1:10
    println(rpad(num_pkg_req[i][2],20," "), num_pkg_req[i][1]-1)
end