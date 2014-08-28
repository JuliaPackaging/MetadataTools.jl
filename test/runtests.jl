using MetadataTools

pkgs = get_all_pkg()
map(get_upper_limit, pkgs)
dump(get_pkg_info(pkgs[1]))