#----------------------------------------------------------------------
# MetadataTools
# https://github.com/IainNZ/MetadataTools.jl
# (c) Iain Dunning 2015
# Licensed under the MIT License
#----------------------------------------------------------------------
# graph_stats.jl
# Calculate some rankings for package connectedness
#----------------------------------------------------------------------

using MetadataTools

# Load in all the package data from METADATA
pkgmeta = get_all_pkg()

# Build a PkgGraph with edges A->B if A directly requires B
pg = make_dep_graph(pkgmeta)
# Count size of every connected subgraph obtained by traversing the
# dependency graph starting from each package
pkg_req_counts = Any[]
for pkg in keys(pkgmeta)
    # Don't warn about cycles, we just want total counts anyway
    g = get_pkg_dep_graph(pkg, pg, cyclewarn=false)
    req_count = MetadataTools.numpackages(g)
    push!(pkg_req_counts, (req_count,pkg))
end
sort!(pkg_req_counts, rev=true)  # Sort descending
println("Top 10 packages by number of packages depended on:")
for (count, pkg) in pkg_req_counts[1:10]
    println(rpad(pkg,30," "), count-1)
end

# Build a graph with edges A->B if A is directly required by B
pgrev = make_dep_graph(pkgmeta, reverse=true)
# Count size of every subgraphs like above
pkg_req_counts = Any[]
for pkg in keys(pkgmeta)
    g = get_pkg_dep_graph(pkg, pgrev, cyclewarn=false)
    req_count = MetadataTools.numpackages(g)
    push!(pkg_req_counts, (req_count,pkg))
end
sort!(pkg_req_counts, rev=true)  # Sort descending
println("Top 10 packages by number of packages that depend on them:")
for (count, pkg) in pkg_req_counts[1:10]
    println(rpad(pkg,30," "), count-1)
end