# test additional functionality targeting installed packages 
#

using MetadataTools
using MetadataTools.installedPkgStatus
using Graphs

pkgs = pkgInstalledAsPkgMeta()
for pel in pkgs
    println(pel)
end

function versionToString(v::VersionNumber)
    v == typemax(VersionNumber) && return "*Infty*"
    pre = isempty(v.prerelease) ? "" : "-$(v.prerelease[1])."
    bld = isempty(v.build)      ? "" : "+Commit=$(v.build[1])."
    (v.major == 0 && v.minor == 0 && v.patch == 0) ? "$pre$bld" :
                  "$(v.major).$(v.minor).$(v.patch)$pre$bld"
end


import Graphs.attributes 
function Graphs.attributes{G<:AbstractGraph}(vtx::MetadataTools.PkgMeta,g::G)
     rd = Graphs.AttributeDict()
     rd["label"]=vtx.name * "\n" * versionToString(vtx.versions[1].ver)
     rd
end

# see if we may use the MetadataTools interface: 
g= get_pkgs_dep_graph(pkgs)
println("Num vertices in full graph =", num_vertices(g))
println("Num edges in full graph=", num_edges(g))


plot(g)

gr= get_pkgs_dep_graph(pkgs; reverse=true)
println("Num vertices in full graph (reverse)=", num_vertices(gr))
println("Num edges in full graph (reverse)=", num_edges(gr))

#try the display interface 
plot(gr)

for (name,direction) in [("Quaternions",false) ("Romeo",true) ("Romeo",false)  ]
    println("\nOutput for package $name")
    pk=pkgs[name]
    println("name=", pk.name, "\turl=", pk.url,"\tlen(versions)=",length(pk.versions))
    
    for v in pk.versions
        println("\tver=",v.ver,"\trequires=",v.requires)
    end
    
    println("Vertex index for $name=", vertex_index(pk,g), "\t (0 shows absence")
    sg = get_pkg_dep_graph(pk, g)
    println("Num vertices in subgraph depending on $name=", num_vertices(sg))
    println("Num edges in subgraph depending on $name=", num_edges(sg))

    # write a .dot to file to be processed by dot or neato
    rev = direction ? "_rev" :""
    to_dot( sg, "tp_$(name)$(rev).dot")
    
    ul = get_upper_limit(pk)
    println("Upper limit name=", ul)
    println("End    for package $name\n+++ +++\n")
end
