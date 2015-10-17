#-----------------------------------------------------------------------
# MetadataTools
# https://github.com/IainNZ/MetadataTools.jl
#-----------------------------------------------------------------------
# Copyright (c) 2015: Iain Dunning
# Licensed under the MIT License
#-----------------------------------------------------------------------
# graph_stats.jl
# Calculate some rankings for package connectedness
#----------------------------------------------------------------------

using MetadataTools

# Load in all the package data from METADATA
pkgmeta = get_all_pkg()

# Build a PkgGraph with edges A->B if A directly requires B
pg = make_dep_graph(pkgmeta)
total_pkgs = size(pg)

# Count size of every connected subgraph obtained by traversing the
# dependency graph starting from each package
pkg_req_counts = Any[]
for pkg in keys(pkgmeta)
    # Don't warn about cycles, we just want total counts anyway
    g = get_pkg_dep_graph(pkg, pg)
    req_count = size(g)
    push!(pkg_req_counts, (req_count,pkg))
end
sort!(pkg_req_counts, rev=true)  # Sort descending
print_with_color(:blue, "Top packages by number of packages depended\n")
print_with_color(:blue, "on, directly or indirectly:\n")
for (count, pkg) in pkg_req_counts[1:10]
    print(rpad(pkg,30," "))
    @printf("%4d / %4d\n", count-1, total_pkgs)
end
println()

# Do the same, but only counting immediate dependencies
pkg_req_counts = Any[]
for pkg in keys(pkgmeta)
    # Don't warn about cycles, we just want total counts anyway
    g = get_pkg_dep_graph(pkg, pg, depth=2)
    req_count = size(g)
    push!(pkg_req_counts, (req_count,pkg))
end
sort!(pkg_req_counts, rev=true)  # Sort descending
print_with_color(:blue, "Top packages by number of packages depended\n")
print_with_color(:blue, "on, directly:\n")
for (count, pkg) in pkg_req_counts[1:10]
    print(rpad(pkg,30," "))
    @printf("%4d / %4d\n", count-1, total_pkgs)
end
println()

# Build a graph with edges A->B if A is directly required by B
pgrev = make_dep_graph(pkgmeta, reverse=true)

# Count size of every subgraphs like above
pkg_req_counts = Any[]
for pkg in keys(pkgmeta)
    g = get_pkg_dep_graph(pkg, pgrev)
    req_count = size(g)
    push!(pkg_req_counts, (req_count,pkg))
end
sort!(pkg_req_counts, rev=true)  # Sort descending
print_with_color(:blue, "Top packages by number of packages that depend\n")
print_with_color(:blue, "on them, directly or indirectly:\n")
for (count, pkg) in pkg_req_counts[1:10]
    print(rpad(pkg,30," "))
    @printf("%4d / %4d\n", count-1, total_pkgs)
end
println()

# Same, but only direct dependencies
pkg_req_counts = Any[]
for pkg in keys(pkgmeta)
    g = get_pkg_dep_graph(pkg, pgrev, depth=2)
    req_count = size(g)
    push!(pkg_req_counts, (req_count,pkg))
end
sort!(pkg_req_counts, rev=true)  # Sort descending
print_with_color(:blue, "Top packages by number of packages that depend\n")
print_with_color(:blue, "on them, directly:\n")
for (count, pkg) in pkg_req_counts[1:10]
    print(rpad(pkg,30," "))
    @printf("%4d / %4d\n", count-1, total_pkgs)
end
