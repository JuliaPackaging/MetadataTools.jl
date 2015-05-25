# test additional functionality targeting installed packages 
#

using MetadataTools
using MetadataTools.installedPkgStatus
using Graphs

pkgs = pkgInstalledAsPkgMeta()
for pel in pkgs
    println(pel)
end

# see if we may use the MetadataTools interface: 
g= get_pkgs_dep_graph(pkgs; reverse=true)
println("Num vertices in full graph =", num_vertices(g))
println("Num edges in full graph=", num_edges(g))



for name in ["Meshes" "Romeo" "Options"]
    println("Output for package $name")
    pk=pkgs[name]
    #@show pk
    println("Vertex index for $name=", vertex_index(pk,g), "\t (0 shows absence")
    sg = get_pkg_dep_graph(pk, g)
    println("Num vertices in subgraph depending on $name=", num_vertices(sg))
    println("Num edges in subgraph depending on $name=", num_edges(sg))

    ul = get_upper_limit(pk)
    println("Upper limit name=", ul)
    println("End    for package $name\n+++ +++\n")
end
