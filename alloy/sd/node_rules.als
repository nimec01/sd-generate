// About fork/join nodes
module node_rules // Most constraints of fork and join nodes, but some constraints are directly with the signatures

open components_sig as components // import all signatures

// If two (or more) arrows leave the same such fork node, they must go to distinct parallel regions.
pred forkNodesGoToDistinctParallelRegions{
        all fn : ForkNodes | one rs : RegionsStates | (Flows <: from).fn.to in nodesInThisAndDeeper[rs]
                and no r : rs.contains, disj f1, f2 : (Flows <: from).fn |
                        (f1 + f2).to in nodesInThisAndDeeper[r]
}

// If two (or more) arrows enter the same such join node, they must come from distinct parallel regions.
pred joinNodesComeFromDistinctParallelRegions{
        all jn: JoinNodes | one rs: RegionsStates | (Flows <: to).jn.from in nodesInThisAndDeeper[rs]
                and no r : rs.contains, disj f1, f2 : (Flows <: to).jn |
                        (f1 + f2).from in nodesInThisAndDeeper[r]
}

fact{
        forkNodesGoToDistinctParallelRegions
        joinNodesComeFromDistinctParallelRegions
        disj [EndNodes, (Flows <: from).ForkNodes.to] // No transitions between end nodes and fork nodes (see example "https://github.com/fmidue/ba-zixin-wu/blob/master/examples/MyExample3.svg")
        disj [StartNodes + HistoryNodes, (Flows <: to).JoinNodes.from] // No transitions between start/history nodes and join nodes (It excludes the example "https://github.com/fmidue/ba-zixin-wu/blob/master/examples/MyExample2.svg")
        disj [ForkNodes + JoinNodes, (Flows <: from).(ForkNodes + JoinNodes).to] // No consecutive fork/join nodes
        all n1: ForkNodes & (Flows <: from).(StartNodes + HistoryNodes).to |
                from.n1.label = EmptyTrigger // If a fork node is reached from a start state or history node, it is not left by an arrow with non-empty transition label.
        all n1: (ForkNodes + JoinNodes) |
                to.n1.label = EmptyTrigger or from.n1.label = EmptyTrigger // No such node is both entered and left by arrows with non-empty transition label.
}
