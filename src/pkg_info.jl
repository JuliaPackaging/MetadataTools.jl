#######################################################################
# get_pkg_info
# Get information from Github (etc?) about a package.
function get_pkg_info(pkgs::PkgMetaDict; token=nothing)
    return [p[1] => get_pkg_info(p[2],token=token) for p in pkgs]
end
function get_pkg_info(pkg::PkgMeta; token=nothing)
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
            response = Requests.text(Requests.get(url))
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
    println(pkg_url)
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
    #sleep(0.5) # Avoid rate limiting?
    url = "https://api.github.com/repos/$(owner_pkg)$(token_arg)"
    req1 = JSON.parse(retry_get(url))
    # Deal with case where somehow the entry is there but
    # null, instead of just being absent.
    if get(req1, "html_url", nothing) == nothing
        req1["html_url"] = "No URL available."
    end
    if get(req1, "description", nothing) == nothing
        req1["description"] = "No desciption available."
    end
    if get(req1, "homepage", nothing) == nothing
        req1["homepage"] = "No homepage available."
    end


    # Request 2 gets contributor information, including their name,
    # website, and commit count
    # API: GET /repos/:owner/:repo/stats/contributors
    # https://developer.github.com/v3/repos/statistics/#contributors
    #sleep(0.5) # Avoid rate limiting?
    #url = "https://api.github.com/repos/$(owner_pkg)/stats/contributors$(token_arg)"
    #req2 = JSON.parse(retry_get(url))
    #if typeof(req2) <: Dict
    #    warn("$url returned error message: $req2")  # probably caused by move
    #    req2 = {}
    #end

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
        (@compat Tuple{Int,Contributor})[]
        #(
        #    con["total"], 
        #    Contributor(con["author"]["login"],con["author"]["html_url"]))
        #    for con in req2]
        )
end