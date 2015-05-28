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

using MetadataTools
import MetadataTools.PkgMeta
import MetadataTools.PkgMetaVersion

export pkgInstalledAsPkgMeta


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
     #   extract the info from the git remote -v command
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

function pkgInstalledAsPkgMeta()
    #println("In  pkgInstalledAsPkgMeta")
    pkgInstalled = Pkg.installed()   
    pkgINames = sort(collect(keys(pkgInstalled)))
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

end #module installedPkgStatus
