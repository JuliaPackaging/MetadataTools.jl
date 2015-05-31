module test4
using MetadataTools
using MetadataTools.GraphAttr
using MetadataTools.GraphAlgos
using MetadataTools.installedPkgStatus
using Graphs

## Format output nodes (from MetaRegInfo.jl)

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
     if vtx.url[1:15] == "git://localhost"
         rd["color"]="bisque"
         rd["shape"]="box"
         rd["style"]="filled"
         
     end
     if length(vtx.versions)>0
        rd["label"]=vtx.name * "\n" * versionToString(vtx.versions[end].ver)
     else
        rd["label"]=vtx.name
     end    
     rd
end
import MetadataTools.GraphAttr.graphAttrib
MetadataTools.GraphAttr.graphAttrib.attributeFn  = graphAttrs

#==
import MetadataTools.GraphAlgos.value_single, MetadataTools.GraphAlgos.value_pair

function  MetadataTools.GraphAlgos.value_single(v)
    (v.name,v.url)
end

function MetadataTools.GraphAlgos.value_pair{E,G<:AbstractGraph}(e::E,g::G)
    o1 = (source(e,g).name, source(e,g).url)
    o2 = (target(e,g).name, target(e,g).url)
    (o1,o2)
end

==#

##########################  Function to resolve merge conflics
@doc """ GENERIC:  This function receives as arguments:
              regvx :   vertex of the first graph (registered packages)
              instvx :   vertex of the second graph (installed packages)
              The conflict is detected meaning the output of the functions
                    MetadataTools.GraphAlgos.value_single and
                    MetadataTools.GraphAlgos.value_pair   cannot distinguish pairs
              This function may:
                    1) decide to identify the vertex instvx  with the corresponding
                       regvx. In this case, the caller may need to
                       modify the edge to be transferred. **CLARIFY**
                    2) decide not to identify the vertex instvx, therefore cause
                       the caller to create a new vertex;

              This function returns true if a vertex must be inserted (case 2)
              (not identified),   false otherwise.

          SPECIFIC TO THIS APPLICATION
                We choose:
                -to merge (identify) vertices when the commit ids are identical
                - when inserted, a special edge must be added from regvx to
                  instvx
     """ ->
function mergeConflict( regvx::MetadataTools.PkgMeta,
                        instvx::MetadataTools.PkgMeta)
         regVer  = regvx.versions[end].ver
         instVer = instvx.versions[1].ver
         regCommit  = regvx.versions[end].sha
         instCommit = instvx.versions[1].sha
         if regCommit == instCommit
             # same commit: we identify the vertices and do nothing
             # TBD: check and explain here how/why  edges will adjust
             return false
         else
             # different commits: add the vertex to g
             return true
         end
end

##########################  Graph collection and merge
#pkgname = "Cairo"
pkgname = "Reactive"

pkgs = get_all_pkg()
pk= pkgs[pkgname]
pkgsI =  pkgInstalledAsPkgMeta()
pkI= pkgsI[pkgname]


g   = get_pkgs_dep_graph(pkgs)
sg  = get_pkg_dep_graph(pk, g)
gr  = get_pkgs_dep_graph(pkgs;reverse=true)
sgr =  reverseArrows(get_pkg_dep_graph(pk, gr))
mg  = GraphAlgos.merge(sg,sgr)

gI = get_pkgs_dep_graph(pkgsI)
sgI = get_pkg_dep_graph(pkI, gI)
grI = get_pkgs_dep_graph(pkgsI;reverse=true)
sgrI = reverseArrows(get_pkg_dep_graph(pkI, grI))
mgI  = GraphAlgos.merge(sgI,sgrI)

fing =  GraphAlgos.merge(mg, mgI; resolveProc=mergeConflict)
to_dot(fing,"dotImgs/T4merge.dot")

end # module test4
