######################################################################
# This file:
# (c) Alain Lichnewsky, 2015
# Licensed under the MIT License

# Package :  MetadataTools
# https://github.com/IainNZ/MetadataTools.jl
# (c) Iain Dunning 2014
# Licensed under the MIT License
######################################################################

module MetaRegInfo

using MetadataTools
using MetadataTools.GraphAttr
using Graphs
using MetadataTools.installedPkgStatus

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
     if length(vtx.versions)>0
        rd["label"]=vtx.name * "\n" * versionToString(vtx.versions[end].ver)
     else
        rd["label"]=vtx.name
     end    
     rd
end

import MetadataTools.GraphAttr.graphAttrib
MetadataTools.GraphAttr.graphAttrib.attributeFn  = graphAttrs


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
                   direction::Bool,
                   dotFileName::Union(Void,String),
                   installed::Bool)
    
   allPkgs = installed ? pkgInstalledAsPkgMeta() : get_all_pkg()
   allGraph =  get_pkgs_dep_graph(allPkgs; reverse=direction)
   g = pkgn==nothing?
                allGraph :
                safe_get_pkg_dep_graph(pkgn,allPkgs, allGraph)
   g == nothing && exit(1)
   println("Num vertices=", num_vertices(g))
   println("Num edges=", num_edges(g))

   # write a .dot to file to be processed by dot or neato
    to_dot( g,dotFileName)
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
      "--dot"
               help="Specify dot file name (output)"
               arg_type = String
       "--pkg"
               help="Specify pkg name, if ommitted full dependency graph"
               arg_type = String
     end    

     s.epilog = """
          Node legends:
            for installed packages:
                  MOD   : the package has been modified since it was tag (by some commits) 
                  NTAG  : no tag available (showing commit id)
                  DIRTY : TBD (we do not recognize dirty packages)
    """
    parsed_args = parse_args(s) # the result is a Dict{String,Any}

    pkgname =parsed_args["pkg"]
    rev = parsed_args["rev"]
    dotFilename =  parsed_args["dot"]
    installed = parsed_args["installed"]
    real_main( pkgname, rev, dotFilename, installed )
end

end # module MetaRegInfo
using  MetaRegInfo

main(ARGS)
