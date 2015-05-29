
using MetadataTools
using MetadataTools.GraphAttr
using MetadataTools.GraphAlgos
using MetadataTools.installedPkgStatus
using Graphs

pkgs = get_all_pkg()
pk= pkgs["Cairo"]
pkgsI =  pkgInstalledAsPkgMeta()
pkI= pkgsI["Cairo"]


g = get_pkgs_dep_graph(pkgs)
sg = get_pkg_dep_graph(pk, g)

gI = get_pkgs_dep_graph(pkgsI)
sgI = reverseArrows(get_pkg_dep_graph(pkI, gI))

println("\n+++++FIRST MERGE")
mg =  GraphAlgos.merge(sg,sgI)
to_dot(mg,"dotImgs/T4merge.dot")

