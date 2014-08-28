#######################################################################
# MetadataTools
# https://github.com/IainNZ/MetadataTools.jl
# (c) Iain Dunning 2014
# Licensed under the MIT License
#######################################################################

module MetadataTools

import Requests, JSON

export get_pkg, get_all_pkg, get_upper_limit, get_pkg_info

#######################################################################
# PkgMeta           Represents a packages entry in METADATA.jl
# PkgMetaVersion    Represents a version of a package in METADATA.jl
immutable PkgMetaVersion
    ver::VersionNumber
    sha::String
    requires::Vector{String}
end
immutable PkgMeta
    name::String
    url::String
    versions::Vector{PkgMetaVersion}
end

function printer(io::IO, pmv::PkgMetaVersion)
    print(io, "  ", pmv.ver, ",", pmv.sha[1:6])
    map(r->print(io, ",",r), pmv.requires)
end
Base.print(io::IO, pmv::PkgMetaVersion) = printer(io,pmv)
Base.show(io::IO, pmv::PkgMetaVersion) = printer(io,pmv)

function printer(io::IO, pm::PkgMeta)
    println(io, pm.name, "   ", pm.url)
    for v in pm.versions[1:end-1]
        println(io, v)
    end
    if length(pm.versions) >= 1
        print(io, pm.versions[end])
    end
end
Base.print(io::IO, pm::PkgMeta) = printer(io,pm)
Base.show(io::IO, pm::PkgMeta) = printer(io,pm)

#######################################################################
# Contributor           A package contributor as defined by Github
# PkgInfo               Package info obtained from Github
immutable Contributor
    username::String
    url::String
end
immutable PkgInfo
    html_url::String  # URL of repo, in constrast to METADATA url
    description::String
    homepage::String
    stars::Int
    watchers::Int
    contributors::Vector{(Int,Contributor)}  # (commit_count,Contrib.)
end

#######################################################################
# get_pkg 
#   return a structure with all information about the package listed
#   in METADATA, e.g.
#
#   julia> get_pkg("DataFrames")
#   DataFrames   git://github.com/JuliaStats/DataFrames.jl.git
#     0.0.0,a63047,Options,StatsBase
#     0.1.0,7b1c6b,julia 0.1- 0.2-,Options,StatsBase
#     0.2.0,b5f0fe,julia 0.2-,GZip,Options,StatsBase
#     ...
#     0.5.7,a8ae61,julia 0.3-,DataArrays,StatsBase 0.3.9+,GZip,Sort...
#
function get_pkg(pkg_name::String; meta_path::String=Pkg.dir("METADATA"))
    !isdir(meta_path) && error("Couldn't find METADATA folder at $meta_path")

    pkg_path = joinpath(meta_path,pkg_name)
    !isdir(pkg_path) && error("Couldn't find $pkg_name at $pkg_path")
    
    url_path = joinpath(pkg_path,"url")
    !isfile(url_path) && error("Couldn't find url for $pkg_name (expected $url_path)")
    url = chomp(readall(url_path))

    vers_path = joinpath(pkg_path,"versions")
    !isdir(vers_path) &&
        # No versions tagged
        return PkgMeta(pkg_name, url, PkgMetaVersion[])
    
    vers = PkgMetaVersion[]
    for dir in readdir(vers_path)
        ver_num = convert(VersionNumber, dir)
        ver_path = joinpath(vers_path, dir)
        sha = chomp(readall(joinpath(ver_path,"sha1")))
        req_path = joinpath(ver_path,"requires")
        reqs = String[]
        if isfile(req_path)
            req_file = map(chomp,split(readall(req_path),"\n"))
            for req in req_file
                length(req) == 0 && continue
                req[1] == '#' && continue
                push!(reqs, req)
            end
        end
        push!(vers,PkgMetaVersion(ver_num,sha,reqs))
    end
    # Sort ascending by version number
    sort!(vers, by=(v->v.ver))
    return PkgMeta(pkg_name, url, vers)
end

#######################################################################
# get_all_pkg
# Walks through the METADATA folder, returns a vector of PkgMetas
# for every package found.
function get_all_pkg(; meta_path::String=Pkg.dir("METADATA"))
    !isdir(meta_path) && error("Couldn't find METADATA folder at $meta_path")
    
    pkgs = PkgMeta[]
    for fname in readdir(meta_path)
        # Skip files
        !isdir(joinpath(meta_path, fname)) && continue
        # Skip "hidden" folders
        (fname[1] == '.') && continue
        push!(pkgs, get_pkg(fname, meta_path=meta_path))
    end

    return pkgs
end

#######################################################################
# get_upper_limit
# Run through all versions of a package to try to determine if there
# is an upper limit on the Julia version this package is installable
# on. Does so by checking all Julia requirements across all versions.
# If there is a limit, returns that version, otherwise v0.0.0
function get_upper_limit(pkg::PkgMeta)
    upper = v"0.0.0"
    all_max = true
    for ver in pkg.versions
        julia_max_ver = v"0.0.0"
        # Check if there is a Julia max version dependency
        for req in ver.requires
            !contains(req,"julia") && continue
            s = split(req," ")
            length(s) != 3 && continue
            julia_max_ver = convert(VersionNumber,s[3])
            break
        end
        # If there wasn't, then at least one version will work on
        # any Julia, so stop looking
        if julia_max_ver == v"0.0.0"
            all_max = false
            break
        else
            # Only record the highest max version
            if julia_max_ver > upper
                upper = julia_max_ver
            end
        end
    end
    return all_max ? upper : v"0.0.0"
end

#######################################################################
# get_pkg_info
# Get information from Github (etc?) about a package.
function get_pkg_info(pkg::MetadataTools.PkgMeta; token=nothing)
    get_pkg_info(pkg.url, token=token)
end
function get_pkg_info(pkg_url::String; token=nothing)
    if contains(pkg_url, "github")
       return get_pkg_info_github(pkg_url::String, token=token)
    else
        error("get_pkg_info only supports packages hosted: GitHub.")
    end
end

# Helper function
function retry_get(url; max_attempts=3, sleep_time=0.5)
    failures = 0
    response = nothing
    while response == nothing
        try
            response = Requests.get(url).data
        catch
            failures += 1
            sleep(sleep_time)
        end
        if failures == max_attempts
            error("Failed to get data from $url 3 times!")
        end
    end
    return response
end

# Github version [not exported]
function get_pkg_info_github(pkg_url::String; token=nothing)
    # If a token is provided, use it
    token_arg = (token == nothing) ? "" : "?access_token=$(token)"

    # Extract owner/pkgname.jl from METADATA standardized URL, e.g.
    # git://github.com/owner/pkgname.jl.git
    url_split = split(pkg_url, "/")
    owner_pkg = url_split[end-1] * "/" * url_split[end][1:end-4]
    
    # Request 1 gets general information about package, containing:
    # description, homepage, stargazers_count, watchers_count        
    # API: GET /repos/:owner/:repo/
    # https://developer.github.com/v3/repos/#get
    url = "https://api.github.com/repos/$(owner_pkg)$(token_arg)"
    req1 = JSON.parse(retry_get(url))
    # Deal with case where somehow the homepage entry is there but
    # null, instead of just being absent.
    if get(req1, "homepage", nothing) == nothing
        req1["homepage"] = "No homepage available."
    end

    # Request 2 gets contributor information, including their name,
    # website, and commit count
    # API: GET /repos/:owner/:repo/stats/contributors
    # https://developer.github.com/v3/repos/statistics/#contributors
    url = "https://api.github.com/repos/$(owner_pkg)/stats/contributors$(token_arg)"
    req2 = JSON.parse(retry_get(url))

    # Request 3 gets the clone count, and isn't officially supported
    # by GitHub. Need to be logged in for it to work, so disabled until
    # a work around
    #https://github.com/JuliaOpt/JuMP.jl/graphs/clone-activity-data
    #=url = "https://github.com/$(owner_pkg)/graphs/clone-activity-data"
    println(url)
    println(Requests.get(url).headers)
    req3 = retry_get(url)
    println(req3)=#


    return PkgInfo(
        get(req1, "html_url", "No URL available."),
        get(req1, "description", "No desciption available."),
        get(req1, "homepage", "No homepage available."),
        get(req1, "stargazers_count", -1),
        get(req1, "subscribers_count", -1),
        (Int,Contributor)[(
            con["total"], 
            Contributor(con["author"]["login"],con["author"]["html_url"]))
            for con in req2]
        )
end

end  # module