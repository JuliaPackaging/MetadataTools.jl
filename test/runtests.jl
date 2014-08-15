using MetadataTools

pkgs = get_all_pkg(joinpath(Pkg.dir("METADATA")))
map(get_upper_limit, pkgs)