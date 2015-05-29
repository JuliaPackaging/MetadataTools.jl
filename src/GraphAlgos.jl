######################################################################
# This file:
# (c) Alain Lichnewsky, 2015
# Licensed under the MIT License

# Package :  MetadataTools
# https://github.com/IainNZ/MetadataTools.jl
# (c) Iain Dunning 2014
# Licensed under the MIT License
######################################################################

## Additional graph algorithms
##

module GraphAlgos
export reverseArrows, merge

using Graphs
using MetadataTools

#== There is an issue with PkgMeta (MetadataTools commit=c139cdbe2a42b36*):
     1) equality in PkgMeta (same names and urls) is not equivalent to
       structural equality (object_id)
     2) we chose to respect the requirement (stdlib/base) that
        object_id(x) =  object_id(y)    <==> hash(x) == hash (y)
     3) structural equality implies equality in PkgMeta, but not the converse

     Now Graphs (Graphs.jl) function well if all vertices in a graph are distinct
     which means structurally distinct (and which is not enforced by the
     constructor, therefore need to be enforced by the user.

     We consider that it would be confusing to have in the same graph distinct
     vertices which compare equal (isequal), therefore we merge such nodes.

     In the merge function, the merging strategy is left for parametrization
     by the user (since merging is dependent on user level semantics). However
     the user should ensure that in the same graph their is no pair of
     vertices which compare equal (isequal).
==#


@doc """ This function takes as argument a directed graph and emits a new graph
         with same vertices and reversed edges
""" ->
function reverseArrows{G<:AbstractGraph}(g::G)
   is_directed(g) || error("Graph is not directed")
                  ## chose not to return a simple copy! (and neither to alias)
   ng = Graphs.graph( collect(vertices(g)), Graphs.Edge{MetadataTools.PkgMeta}[],
                      is_directed=true)
   for vtx in edges(g)       
       Graphs.add_edge!(ng,target(vtx),source(vtx))
   end
   ng
end

import Base.in
@doc """  Check that a vertex is in a graph, using structural equality
     """ -> 
function Base.in{V,G<:AbstractGraph}(v::V,g::G)
    haskey(v, g.indexof)
end

         
#== These two functions permit to uniquely identify vertices
    in our graphs; based on semantic equality (as defined by the user,
    for instance see isequal in MetadataTools.jl, not structural equality);
    object_id is not effective since there might be  copies or several nodes
    
    This will need  to be user parametrizable for GraphAlgos to become
    flexible. (First we will try to simply redefine these...)
==#
         
function value_single(v)
    v.name
end

function value_pair{E,G<:AbstractGraph}(e::E,g::G)
    o1 = source(e,g).name
    o2 = target(e,g).name
    (o1,o2)
end
    
@doc """ This function takes two (directed) graphs (same type) as arguments and returns a
         new graph with vertices : the union of the sets of vertices, and
         for edges : the set one edge between to vertices if such exists in either of the
         input graphs.
""" ->
function GraphAlgos.merge{G<:AbstractGraph}(g1::G, g2::G)
     is_directed(g1) == is_directed(g2) || error("mix of directedness!!")

    #==  Algorithm:        
        1) we store in new graph g a copy of g1 (vertices + edges)
        2) we add the vertices in g2 not in g1
        3) at this step all vertices of v have been included;
           for each edge in g2, if not redundant with edges  already
           in g we  insert it.
        expected cost:  (1) O(numEdge(g1) +  numVert(g1)*(1+log( numVert(g1))))
                        (2) O(numVert(g2)* (1+log(numVert(g)))
                        (3) O(numEdge(g2)* (1+log(numVert(g)))
        bound < (1+log(numVert(g))*(numEdge(g1) + numVert(g1) + numVert(g2) + numEdge(g2)  )
    ==#
     g =  Graphs.graph( collect(vertices(g1)),  collect(edges(g1)),
                        is_directed = is_directed(g1))

     ## this dict is used to check that we are not introducing semantically
     ## equal vertices (isequal)
     vertexDict = Dict{Any,Bool}()
     for v in vertices(g)
         vertexDict[value_single(v)]=true
     end
     ## introduce new vertices when not equal; in some applications, just
     ## dropping is not sufficient ( or might be inadequate ).
     for v in vertices(g2)
         if !haskey(vertexDict,value_single(v))
             add_vertex!(g,v)
             vertexDict[value_single(v)]=true
         end
     end

    # Debug:check that all vertices are indeed distinct
      snames =  sort(map( x-> x.name, vertices(g)))
      for i in 1:(length(snames)-1)
          @assert snames[i] != snames[i+1]
      end
                 
     # now, all vertices have unique index in g
     # make a fast accessible structure indicating the existence of edges in g
     edgeDict = Dict{Tuple{Any,Any},Bool}()
     for e in edges(g)
         edgeDict[value_pair(e,g)] = true
     end
                 
     for e in edges(g2)
         vp = value_pair(e,g2)
         if !haskey(edgeDict, vp)
            add_edge!(g,source(e,g2),target(e,g2))
            edgeDict[vp] = true
         end
     end

    g
end
    


end # module GraphAlgos
