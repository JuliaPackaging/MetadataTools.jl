module test1
using MetadataTools
using Graphs


function versionToString(v::VersionNumber)
    v == typemax(VersionNumber) && return "*Infty*"
    pre = isempty(v.prerelease) ? "" : "-$(v.prerelease)."
    bld = isempty(v.build)      ? "" : "+$(v.build)."
    (v.major == 0 && v.minor == 0 && v.patch == 0) ? "$pre$bld" :
                  "$(v.major).$(v.minor).$(v.patch)$pre$bld"
end

function graphAttrs{G<:AbstractGraph}(vtx::MetadataTools.PkgMeta,g::G)
     rd = Graphs.AttributeDict()
     rd["label"]=vtx.name * "\n" * versionToString(vtx.versions[1].ver)
     rd
end

import Main.graphAttrib
@show Main.graphAttrib
Main.graphAttrib.attributeFn  = graphAttrs

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

function versionToString(v::VersionNumber)
    v == typemax(VersionNumber) && return "*Infty*"
    pre = isempty(v.prerelease) ? "" : "-$(v.prerelease[1])."
    bld = isempty(v.build)      ? "" : "+Commit=$(v.build[1])."
    (v.major == 0 && v.minor == 0 && v.patch == 0) ? "$pre$bld" :
                  "$(v.major).$(v.minor).$(v.patch)$pre$bld"
end


function graphAttrs{G<:AbstractGraph}(vtx::MetadataTools.PkgMeta,g::G)
     rd = Graphs.AttributeDict()
     # since vtx.versions is sorted by ascending, we want to
     # access the last entry
     rd["label"]=vtx.name * "\n" * versionToString(vtx.versions[end].ver)
     rd
end

import Main.graphAttrib
@show Main.graphAttrib
Main.graphAttrib.attributeFn  = graphAttrs


#    Test: Cairo: there are circles
for (name,direction) in [("Cairo", false) ("Cairo", true)
                         ("GLAbstraction",false) ("Romeo",false)                         
                         ]
    try
       pk=pkgs[name]
       sg = get_pkg_dep_graph(pk, g)

       # write a .dot to file to be processed by dot or neato
       rev = direction ? "_rev" :""
       to_dot( sg, "dotImgs/tp1_$(name)$(rev).dot")
    catch err
        println("Error for pkg name $name:", err)
        Base.show_backtrace( STDOUT, backtrace())
        println("\n")
    end
end

end # module test1
