######################################################################
# This file:
# (c) Alain Lichnewsky, 2015
# Licensed under the MIT License

# Package :  MetadataTools
# https://github.com/IainNZ/MetadataTools.jl
# (c) Iain Dunning 2014
# Licensed under the MIT License
######################################################################

module test2
# test additional functionality targeting installed packages 
#

using MetadataTools
using MetadataTools.installedPkgStatus
using MetadataTools.GraphAttr
using MetadataTools.GraphAlgos
using Graphs

pkgs = pkgInstalledAsPkgMeta()
for pel in pkgs
    println(pel)
end

function versionToString(v::VersionNumber)
    v == typemax(VersionNumber) && return "*Infty*"
    pre = isempty(v.prerelease) ? "" :
            isa(v.prerelease,Tuple) ?  
                  (length(v.prerelease) > 1 ?
                           v.prerelease[1] * (@sprintf "%d"  v.prerelease[2]):
                           "-$(v.prerelease[1])" ) :
                  "-$(v.prerelease)."
    bld = isempty(v.build)      ? "" :
             isa(v.build,Tuple) ? 
                        (length(v.build) > 1 ?
                            v.build[1] * ( @sprintf "%d"  v.build[2]) :
                            "+$(v.build[1])") :
                       "+$(v.build)." 
    (v.major == 0 && v.minor == 0 && v.patch == 0) ? "$pre$bld" :
                  "$(v.major).$(v.minor).$(v.patch)$pre$bld"
end

function graphAttrs{G<:AbstractGraph}(vtx::MetadataTools.PkgMeta,g::G)
     rd = Graphs.AttributeDict()
     if length(vtx.versions)>0
        rd["label"]=vtx.name * "\n" * versionToString(vtx.versions[end].ver)
     else
        rd["label"]=vtx.name
     end    
     rd
end

import MetadataTools.GraphAttr.graphAttrib
MetadataTools.GraphAttr.graphAttrib.attributeFn  = graphAttrs


# see if we may use the MetadataTools interface: 
g= get_pkgs_dep_graph(pkgs)
println("Num vertices in full graph =", num_vertices(g))
println("Num edges in full graph=", num_edges(g))


to_dot(g,"dotImgs/tp2_all.dot")

gr= get_pkgs_dep_graph(pkgs; reverse=true)
println("Num vertices in full graph (reverse)=", num_vertices(gr))
println("Num edges in full graph (reverse)=", num_edges(gr))

#try the display interface 
plot(gr)

for (name,direction) in [("Quaternions",false) ("GLAbstraction",false) ("Romeo",false)  ("Romeo",true) ]
    println("\nOutput for package $name")
    g= get_pkgs_dep_graph(pkgs;reverse=direction)
    pk = ()
    try
        pk=pkgs[name]
    catch err
        println("Error for pkg name $name:", err)
        Base.show_backtrace( STDOUT, backtrace())
        println("\n")
        continue
    end      
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
    to_dot( direction? reverseArrows(sg): sg, "dotImgs/tp2_$(name)$(rev).dot")
    
    ul = get_upper_limit(pk)
    println("Upper limit name=", ul)
    println("End    for package $name\n+++ +++\n")
end


end # module test2
