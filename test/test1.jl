using MetadataTools
using Graphs

ipkgs = get_all_pkg()
#map(get_upper_limit, values(pkgs))
#dump(get_pkg_info(pkgs["JuMP"]))

g = get_pkgs_dep_graph(get_all_pkg())
println("Num vertices in full graph =", num_vertices(g))
println("Num edges in full graph=", num_edges(g))


#Note: findfirst returns 0 when not found, see src/base/array.jl
#      returns the index of the next matching element; so does vertex_index

pk=pkgs["Gadfly"]
sg = get_pkg_dep_graph(pk, g)
println("Num vertices in subgraph depending on GadFly=", num_vertices(sg))
println("Num edges in subgraph depending on GadFly=", num_edges(sg))


ul = get_upper_limit(pk)
println("Upper limit GadFly=", ul)

