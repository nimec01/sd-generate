module teaching_examples // It is used to generate specific teaching examples

open uml_state_diagram

// It is not necessary, but in order to generate some both manifold and non-boring SDs, we can add it.
pred atLeastOneExitFromCompositeStates{
        all c1: CompositeStates |
                let n1 = nodesInThisAndDeeper[c1], n2 = Nodes - n1 |
                        n2 in (Flows <: from).c1.to // Standard exit
                        or some (n2 & (Flows <: from).n1.to) // Direct or join exit
}

// No regions, no history nodes
pred scenario1{
        no HistoryNodes
        no Regions
        # Nodes > 8
        # Flows > 8
        some HierarchicalStates
        atLeastOneExitFromCompositeStates
}

// Some regions, no history nodes
pred scenario2{
        no HistoryNodes
        some Regions
        # Nodes > 8
        # Flows > 8
        // some HierarchicalStates
        // some ForkNodes
        // some JoinNodes
        atLeastOneExitFromCompositeStates
}

// No regions, some history nodes
pred scenario3{
        some HistoryNodes
        no Regions
        # Nodes > 8
        # Flows > 8
        some HierarchicalStates
        atLeastOneExitFromCompositeStates
}

run scenario1 for 10 but 6 Int