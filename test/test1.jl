######################################################################
# This file:
# (c) Alain Lichnewsky, 2015
# Licensed under the MIT License

# Package :  MetadataTools
# https://github.com/IainNZ/MetadataTools.jl
# (c) Iain Dunning 2014
# Licensed under the MIT License
######################################################################

module test1
using MetadataTools
using MetadataTools.GraphAttr
using Graphs


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

pkgs = get_all_pkg()
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

#    Test: Cairo: there are circles
for (name,direction) in [("Cairo", false) ("Cairo", true)
                         ("GLAbstraction",false) ("Romeo",false)                         
                         ]
    g = get_pkgs_dep_graph( get_all_pkg(); reverse=direction )
    try
       pk=pkgs[name]
       sg = get_pkg_dep_graph( pk, g )

       # write a .dot to file to be processed by dot or neato
       rev = direction  ? "_rev" :""
       to_dot( sg, "dotImgs/tp1_$(name)$(rev).dot")
    catch err
        println("Error for pkg name $name:", err)
        Base.show_backtrace( STDOUT, backtrace())
        println("\n")
    end
end

end # module test1
