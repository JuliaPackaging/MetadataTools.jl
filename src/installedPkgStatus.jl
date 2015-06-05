######################################################################
# This file:
# (c) Alain Lichnewsky, 2015
# Licensed under the MIT License

# Package :  MetadataTools
# https://github.com/IainNZ/MetadataTools.jl
# (c) Iain Dunning 2014
# Licensed under the MIT License
######################################################################

module installedPkgStatus

using  MetadataTools
import MetadataTools.PkgMeta
import MetadataTools.PkgMetaVersion
using  Graphs

export pkgInstalledAsPkgMeta, get_pkg_dep_graph_inst, 
       get_pkgs_dep_graph_inst


function getDependencies(dir)
    deps = Pkg.Reqs.parse(joinpath(dir,"REQUIRE"))
end

function gitUrlsFromRemote(dir)
     #   extract the info from the git remote -v command
     b = readall(`bash -c " cd $dir; git remote -v"`)
     c = split(b,"\n")
     c=="" && return []
     d = map (x -> split(x,r"(\t|\s)"),c)

     #   make sense of it?
end

const  rxTag = Base.compile( 
   r"^                                  # start
(([[:alpha:]]+)\s+([[:alnum:]\.]+)     # keyword  hex-sha
|
([[:alpha:]]+)\s+([^<]+)<([^>]*)>       # keyword  firstname name <mailaddr>
.*                                      # ignored for now
)   
$                                       # end
"x)

function getVersionsPM(vernum::VersionNumber,sha::String, dir)
	versions = Vector{PkgMetaVersion}(0)
        #println("In getVersionsPM $vernum $sha ")

        # get the current tags which contain current commit!!!
        # otherwise they are deemed obsolete
        b = readall(`bash -c " cd $dir; git tag --contains $sha 2>/dev/null"`)
        listTags = split(b,"\n")

        for tag in listTags
            result = Dict{String,Any}()
            tag==""  && continue
            # The echo final step ensures we return a 0 retcode, otherwise
            # julia will complain. I do not know what happens on Windows(TM) 
            b = readall(`bash -c " cd $dir; git tag -v $tag 2>/dev/null; echo"`)
         
            # Analyze, get the most recent tag and its sha   
            for x in split(b,"\n")
                 m = match(rxTag,x)
                 isa(m,Void) && continue
                 if in (m.captures[2],["object" "tag" "type" ])
                    result[ m.captures[2] ]= m.captures[3]
                 elseif (    m.captures[4] == "tagger") 
                    result[ m.captures[4] ]=( m.captures[5],m.captures[6] )
                    break
                 end
             end
        
             # see src/base/version.jl for the format of VersionNumber
             # use the most recent tag, if the sha does not coincide
             # add a prerelease indication "MODIFIED"
             if haskey(result,"object")
                pmvPre = sha !=  result["object"] ? ("MOD",) : ()
                         #we need the 0x for the rare case where the SHA
                         #starts with 8 digits, and does not qualify with version's
                         #format in src/base/version.jl
                pmvBld = ("0x" * ASCIIString(result["object"][1:8]),)
             else
                pmvPre = ("NEW",)
                pmvBld = Tuple{Vararg{ASCIIString}}(())
             end
             tagvn = VersionNumber(tag) #convert tag (string) to VersionNumber type
             vn = VersionNumber(tagvn.major, tagvn.minor, tagvn.patch, pmvPre, pmvBld)

             #By extracting keys we ignore the version information in the 
             #output of getDependencies.
             reqs =map(ASCIIString,keys(getDependencies(dir)))
             push!(versions, PkgMetaVersion(vn,sha,reqs))        
        end
        if length(versions) ==  0
                         # see remark above concerning 0x
             sha1  = "0x" * ASCIIString(sha)[1:8]
             vn = VersionNumber(0,0,0,("NTAG",), (sha1,))
             push!(versions, PkgMetaVersion(vn,sha, Vector{ASCIIString}(0)))                    
        end
        return versions
end


const  rxLog = Base.compile( 
   r"^                                  # start
(([[:alpha:]]+)\s+([[:xdigit:]]+)       # keyword  hex-sha
|
([[:alpha:]]+)\s+([^<]+)<([^>]*)>       # keyword  firstname name <mailaddr>
.*                                      # ignored for now
)   
$                                       # end
"x)


function getCommitInfo(dir::String)
     #   extract the info from the git log (commit installed)
     b = readall(`bash -c " cd $dir; git log --format=\"raw\" -n 1"`)
     c = split(b,"\n")
     result = Dict{String,Any}()
     for x in c 
       m = match(rxLog,x)
       isa(m,Void) && continue
       if m.captures[2] == "commit"
         result[ m.captures[2] ]= m.captures[3]
       elseif ( m.captures[4] == "committer" || m.captures[4] == "author")
         result[ m.captures[4] ]=( m.captures[5],m.captures[6] )
       end
     end
     result
end

function userFilterDirsDefault(sl::Array{ASCIIString,1})
    ret = Array{String,1}(0) 
    # avoid cases where there are 2 directories (and possibly a link)
    # needs improvement (check that we do not have 2 distinct target dirs)
    for i in 1:length(sl)  
        i > 1 &&  sl[i] == sl[i-1] * ".jl" && continue
        push!(ret,sl[i])
    end
    ret
end


function pkgInstalledAsPkgMeta(userFilterDirFn::Function = userFilterDirsDefault)
    #println("In  pkgInstalledAsPkgMeta")
    pkgInstalled = Pkg.installed()   
    pkgINames    = userFilterDirFn( sort( collect( keys( pkgInstalled))))

    dictRet = Dict{String,PkgMeta}()
    for pkgn in pkgINames
       v        =  pkgInstalled[pkgn]        # get the version number installed
       dir      =  joinpath(Pkg.dir(),pkgn)
       urls     =  gitUrlsFromRemote(dir)
       comInfo  =  getCommitInfo(dir)
       versions =  getVersionsPM(v,comInfo["commit"],dir )
       length(versions) > 1 && println("In  pkgInstalledAsPkgMeta, length version for $pkgn =",
                              length(versions))
       gitDir   =  Pkg.Git.dir(dir)
       fix      =  true

       lclPkM   =  PkgMeta(pkgn,urls[1][2],versions)
       dictRet[pkgn]  =  lclPkM
    end
    dictRet
end

#######################################################################
#
#   These are functions from the original package (c) Iain Dunning 2014, 
#   adapted to work with installed packages : METADATA/*/requires but a 
#   REQUIRES file.
#
#######################################################################
# get_pkgs_dep_graph_inst
# Given a vector of packages (i.e. the output of get_all_pkg) build
# a Graphs.jl directed graph, where there is an edge from PkgA to 
# PkgB iff PkgA directly requires PkgB. Alternatively, if reverse
# is true, reverse the direction of the arcs.

typealias PkgGraph Graphs.GenericGraph
typealias PkgMetaDict Dict{String,PkgMeta}

function get_pkgs_dep_graph_inst(pkgs::PkgMetaDict; reverse=false)
    g = Graphs.graph(collect(values(pkgs)), Graphs.Edge{PkgMeta}[], is_directed=true)
    
    for pkg in values(pkgs)
         # we analyze the REQUIRE file
         deps = getDependencies ( joinpath( Pkg.dir(),pkg.name ))
         for dep in deps
            req , versRange =  dep
            if contains(req, "julia")
                # Julia version dependency, skip it
                continue
            end
            other_pkg = pkgs[(req[1] == '@') ? split(req," ")[2] : split(req," ")[1]]
            if reverse
                Graphs.add_edge!(g, other_pkg, pkg)
            else    
                Graphs.add_edge!(g, pkg, other_pkg)
            end
         end
    end

    return g
end

# get_pkg_dep_graph_inst
# Get the dependency graph for a single package by running a BFS/DFS on
# the full dependency graph starting from the desired package
# We do this by creating a Graphs.jl visitor, then just passing that into
# the traversal algorithm
type SubgraphBuilderVisitor <: Graphs.AbstractGraphVisitor
    sub_graph::PkgGraph
    added::Dict{PkgMeta,Bool}
end
SubgraphBuilderVisitor() = SubgraphBuilderVisitor(
        Graphs.graph(PkgMeta[],Graphs.Edge{PkgMeta}[],is_directed=true),
        Dict{PkgMeta,Bool}())
function add_vert_no_dupe(visitor::SubgraphBuilderVisitor, v::PkgMeta)
    if !get(visitor.added, v, false)
        Graphs.add_vertex!(visitor.sub_graph, v)
        visitor.added[v] = true
    end
end
function Graphs.examine_neighbor!(visitor::SubgraphBuilderVisitor, u::PkgMeta, v::PkgMeta, vcolor::Int, ecolor::Int)
    add_vert_no_dupe(visitor, u)
    add_vert_no_dupe(visitor, v)
    Graphs.add_edge!(visitor.sub_graph, u, v)
end

get_pkg_dep_graph_inst(pkg_name::String, pkgs::PkgMetaDict; reverse=false) =
    get_pkg_dep_graph_inst(pkgs[pkg_name], pkgs, reverse=reverse)
get_pkg_dep_graph_inst(pkg::PkgMeta, pkgs::PkgMetaDict; reverse=false) =
    get_pkg_dep_graph_inst(pkg, get_pkgs_dep_graph(pkgs,reverse=reverse))
function get_pkg_dep_graph_inst(pkg::PkgMeta, dep_graph::PkgGraph)
    v = SubgraphBuilderVisitor()
    Graphs.traverse_graph(dep_graph, Graphs.BreadthFirst(), pkg, v)
    return v.sub_graph
end


end #module installedPkgStatus
