using MetadataTools
pkgmeta = get_all_pkg()
pg = make_dep_graph(pkgmeta)
pkg_graph = get_pkg_dep_graph("Gadfly", pg)
