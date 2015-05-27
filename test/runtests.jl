using MetadataTools
using Graphs

type  GraphAttribParametrization
   attributeFn :: Function
end    

function defaultGraphAttribFn{G<:AbstractGraph}(vtx::MetadataTools.PkgMeta,g::G)
     rd = Graphs.AttributeDict()
     rd["label"]=vtx.name
     rd
end

graphAttrib = GraphAttribParametrization(defaultGraphAttribFn)

import Graphs.attributes 
function Graphs.attributes{G<:AbstractGraph}(vtx::MetadataTools.PkgMeta,g::G)
    graphAttrib.attributeFn(vtx,g)
end




include("test1.jl")
include("test2.jl")
