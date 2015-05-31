######################################################################
# This file:
# (c) Alain Lichnewsky, 2015
# Licensed under the MIT License

# Package :  MetadataTools
# https://github.com/IainNZ/MetadataTools.jl
# (c) Iain Dunning 2014
# Licensed under the MIT License
######################################################################

##   Command line interface to building .dot graphs for packages
##   Enter: Julia MetaRegInfo --help
##   for more details

module MetaRegInfo

using MetadataTools
using MetadataTools.GraphAttr
using MetadataTools.installedPkgStatus
using MetadataTools.GraphAlgos
using Graphs

export main

@doc """
     This function returns a string presenting a version number
     like we want it in the .dot output
""" ->
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

@doc """
     This function is used to modify  MetadataTools.GraphAttr.graphAttrib,
     which is used to plot in  Graphs.to_dot (requires PR
     https://github.com/JuliaLang/Graphs.jl/pull/183 )
""" ->
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


function safe_get_pkg_dep_graph(pkgn::String,pkgs, g)
    try
       pk=pkgs[pkgn]
       return get_pkg_dep_graph(pk, g)
    catch err
        println("Error for pkg name $pkgn:", err)
        Base.show_backtrace( STDOUT, backtrace())
        println("\n")
    end
end

function real_main(pkgn::Union(Void,String),
                   reversed::Bool,
                   dotFileName::Union(Void,String),
                   installed::Bool)
    
   allPkgs = installed ? pkgInstalledAsPkgMeta() : get_all_pkg()
   allGraph =  get_pkgs_dep_graph(allPkgs; reverse=reversed)
   g = pkgn==nothing?
                allGraph :
                safe_get_pkg_dep_graph(pkgn,allPkgs, allGraph)
   g == nothing && exit(1)
   println("Num vertices=", num_vertices(g))
   println("Num edges=", num_edges(g))

   # write a .dot to file to be processed by dot or neato
    to_dot( reversed ? reverseArrows(g): g,dotFileName)
end

# merges 2 graphs one from registered, one from installed
function real_main_mergeRI(pkgn::Union(Void,String),
                   reversed::Bool,
                   dotFileName::Union(Void,String))
         pkgs = get_all_pkg()
         pkgsI =  pkgInstalledAsPkgMeta()
         allGraph  =  get_pkgs_dep_graph(pkgs; reverse=reversed)
         allGraphI =  get_pkgs_dep_graph(pkgsI; reverse=reversed)
         g = pkgn==nothing?
                allGraph :
                safe_get_pkg_dep_graph(pkgn,pkgs, allGraph)
         gI = pkgn==nothing?
                allGraphI :
                safe_get_pkg_dep_graph(pkgn,pkgsI, allGraphI)
    
         mg  = GraphAlgos.merge(g,gI; resolveProc=mergeConflict)
         to_dot( reversed ? reverseArrows(mg) : mg,  dotFileName)
end


# merges 2 pivoted graphs one from registered, one from installed
function real_main_mergePRI(pkgn::Union(Void,String),
                   dotFileName::Union(Void,String))
    pkgs = get_all_pkg()
    pk= pkgs[pkgn]
    pkgsI =  pkgInstalledAsPkgMeta()
    pkI= pkgsI[pkgn]


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
    to_dot(fing,dotFileName)
end


# merges 2 graphs giving 2 views with same package as pivot
function real_main_mergePivot(pkgn::Union(Void,String),
                   dotFileName::Union(Void,String),
                   installed::Bool)
    
   allPkgs = installed ? pkgInstalledAsPkgMeta() :  get_all_pkg()
   pk= allPkgs[pkgn]
    
   g = get_pkgs_dep_graph(allPkgs)
   sg = get_pkg_dep_graph(pk, g)

   gr = get_pkgs_dep_graph(allPkgs; reverse=true)
   sgr = reverseArrows(get_pkg_dep_graph(pk, gr))

   mg =  GraphAlgos.merge(sg,sgr)
   mg == nothing && exit(1)

   println("Num vertices=", num_vertices(mg))
   println("Num edges=", num_edges(mg))

   to_dot( mg, dotFileName)
end


using ArgParse

function main(args)
     s = ArgParseSettings(description = "Extract package dependency graph as .dot ")   
     @add_arg_table s begin
      "--installed", "-i"
               help="Use installed package according to ~/julia.d/vnn.mm/"
               action = :store_true
      "--rev"
               help="Reverse graph arrows"
                action = :store_true
      "--pivot"
               help="Merge direct and reverse graphs, --pkg required"
               action = :store_true
      "--both"
               help="Merge registered and installed packages"
               action = :store_true
      "--dot"
               help="Specify dot file name (output)"
               arg_type = String
       "--pkg"
               help="Specify pkg name, if ommitted full dependency graph"
               arg_type = String
     end    

     s.epilog = """
          The program builds a dot file for packages installed or registered.
          When --pkg is specified, the graph is limited on dependencies for the
                     given package.
          When --rev is used, dependencies are reversed: packages depending on
                     the given package are included.
          When --pivot --pkg=...  is used reverse and direct dependencies are merged
          When --both  is used ,the registered and installed views are merged

          Node legends:
            for installed packages:
                  MOD   : the package has been modified since it was tag (by some commits) 
                  NTAG  : no tag available (showing commit id)
                  DIRTY : TBD (we do not recognize dirty packages)
            --both and --pivot may be used together
    """
    parsed_args = parse_args(s) # the result is a Dict{String,Any}

    pkgname =parsed_args["pkg"]
    rev = parsed_args["rev"]
    dotFilename =  parsed_args["dot"]
    installed = parsed_args["installed"]

    if parsed_args["pivot"]
        if parsed_args["both"]
           real_main_mergePRI( pkgname, dotFilename)
        else
           real_main_mergePivot( pkgname, dotFilename, installed )
        end
    elseif parsed_args["both"] 
        real_main_mergeRI( pkgname, rev, dotFilename)
    else
        real_main( pkgname, rev, dotFilename, installed )
    end    
end

end # module MetaRegInfo
using  MetaRegInfo

main(ARGS)
