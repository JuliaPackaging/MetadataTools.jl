module GraphAttr
using MetadataTools
using Graphs

export graphAttrib

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

end # module GraphAttr

