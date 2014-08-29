using MetadataTools
pkgs = get_all_pkg()
#map(get_upper_limit, values(pkgs))
#dump(get_pkg_info(pkgs["JuMP"]))
g = get_pkgs_dep_graph(get_all_pkg())
sg = get_pkg_dep_graph(pkgs["Gadfly"], g)