module test3
using MetadataTools
using MetadataTools.GraphAttr
using MetadataTools.GraphAlgos
using Graphs

pkgs = get_all_pkg()
pk= pkgs["Cairo"]


g = get_pkgs_dep_graph(get_all_pkg())
sg = get_pkg_dep_graph(pk, g)

gr = get_pkgs_dep_graph(get_all_pkg(); reverse=true)
sgr = reverseArrows(get_pkg_dep_graph(pk, gr))

println("\n+++++FIRST MERGE")
mg =  GraphAlgos.merge(sg,sgr)
to_dot(mg,"dotImgs/T1merge.dot")


pk= pkgs["Color"]
sgr2 = reverseArrows(get_pkg_dep_graph(pk, gr))

println("\n+++++SECOND MERGE")
mg2= GraphAlgos.merge(mg,sgr2)
to_dot(mg2,"dotImgs/T2merge.dot")
end # module test3
