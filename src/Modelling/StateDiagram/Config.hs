{-# LANGUAGE NamedFieldPuns, RecordWildCards #-}
{-# LANGUAGE QuasiQuotes #-}

module Modelling.StateDiagram.Config(defaultSDConfig
                                    ,checkSDConfig
                                    ,sdConfigToAlloy
                                    ,SDConfig(..)
                                    ,ChartLimits(..)
                                    ,defaultSDConfigScenario1
                                    ,defaultSDConfigScenario2
                                    ,defaultSDConfigScenario3
                                    )

where

import Modelling.StateDiagram.Alloy(componentsSigRules
                                   ,endstateRules
                                   ,historyRules
                                   ,nameRules
                                   ,nodeRules
                                   ,reachabilityRules
                                   ,regionRules
                                   ,startstateRules
                                   ,substateRules
                                   ,transitionRules
                                   ,trueReachability)
import Data.String.Interpolate(i)
import Control.Applicative (Alternative ((<|>)))

data ChartLimits
  = ChartLimits { regionsStates :: (Int,Int)
                , hierarchicalStates :: (Int,Int)
                , regions :: (Int,Int)
                , normalStates :: (Int,Int)
                , componentNames :: (Int,Int)
                , triggerNames :: (Int,Int)
                , startNodes :: (Int,Int)
                , endNodes :: (Int,Int)
                , forkNodes :: (Int,Int)
                , joinNodes :: (Int,Int)
                , shallowHistoryNodes :: (Int,Int)
                , deepHistoryNodes :: (Int,Int)
                , flows :: (Int,Int)
                , protoFlows :: (Int,Int)
                , totalNodes :: (Int,Int)
                }
  deriving (Show)

data SDConfig
  = SDConfig { bitwidth :: Int
             , enforceNormalStateNames :: Bool
             , distinctNormalStateNames :: Bool
             , noEmptyTriggers :: Bool
             , noNestedEndNodes :: Bool
             , preventMultiEdges :: Maybe Bool
             , enforceOutgoingEdges :: Bool
             , chartLimits :: ChartLimits
             } deriving (Show)

defaultSDConfig :: SDConfig
defaultSDConfig
  = let SDConfig { chartLimits = ChartLimits{ .. }, .. } = defaultSDConfigScenario1
    in SDConfig { preventMultiEdges = Just False
                , chartLimits = ChartLimits{ totalNodes = (10,10)
                                           , normalStates = (7,7)
                                           , flows = (11,11)
                                           , protoFlows = (0,17)
                                           , .. }
                , .. }

defaultSDConfigScenario1 :: SDConfig
defaultSDConfigScenario1
  = SDConfig { bitwidth = 6
             , enforceNormalStateNames = True
             , distinctNormalStateNames = True
             , noEmptyTriggers = True
             , noNestedEndNodes = False
             , preventMultiEdges = Nothing
             , enforceOutgoingEdges = True
             , chartLimits =
                 ChartLimits { regionsStates = (0,0)
                             , hierarchicalStates = (1,1)
                             , regions = (0,0)
                             , normalStates = (5,8)
                             , componentNames = (0,10)
                             , triggerNames = (0,10)
                             , startNodes = (0,10)
                             , endNodes = (0,0)
                             , forkNodes = (0,0)
                             , joinNodes = (0,0)
                             , shallowHistoryNodes = (0,0)
                             , deepHistoryNodes = (0,0)
                             , flows = (0,10)
                             , protoFlows = (0,10)
                             , totalNodes = (8,10)
                             }
             }

defaultSDConfigScenario2 :: SDConfig
defaultSDConfigScenario2
  = SDConfig { bitwidth = 6
             , enforceNormalStateNames = True
             , distinctNormalStateNames = True
             , noEmptyTriggers = True
             , noNestedEndNodes = True
             , preventMultiEdges = Just False
             , enforceOutgoingEdges = True
             , chartLimits =
                 ChartLimits { regionsStates = (0,0)
                             , hierarchicalStates = (1,1)
                             , regions = (2,2)
                             , normalStates = (8,8)
                             , startNodes = (1,1)
                             , endNodes = (1,1)
                             , componentNames = (9,9)
                             , triggerNames = (9,9)
                             , forkNodes = (0,0)
                             , joinNodes = (0,0)
                             , shallowHistoryNodes = (0,0)
                             , deepHistoryNodes = (0,0)
                             , flows = (10,10)
                             , protoFlows = (10,10)
                             , totalNodes = (12,12)
                             }
             }

defaultSDConfigScenario3 :: SDConfig
defaultSDConfigScenario3
  = SDConfig { bitwidth = 6
             , enforceNormalStateNames = True
             , distinctNormalStateNames = True
             , noEmptyTriggers = True
             , noNestedEndNodes = False
             , preventMultiEdges = Just False
             , enforceOutgoingEdges = True
             , chartLimits =
                 ChartLimits { regionsStates = (0,0)
                             , hierarchicalStates = (1,1)
                             , regions = (0,0)
                             , normalStates = (8,8)
                             , componentNames = (11,11)
                             , triggerNames = (11,11)
                             , startNodes = (0,0)
                             , endNodes = (0,0)
                             , forkNodes = (0,0)
                             , joinNodes = (0,0)
                             , shallowHistoryNodes = (1,1)
                             , deepHistoryNodes = (1,1)
                             , flows = (10,10)
                             , protoFlows = (10,10)
                             , totalNodes = (11,11)
                             }
             }

checkSDConfig :: SDConfig -> Maybe String
checkSDConfig SDConfig { bitwidth
                       , enforceNormalStateNames
                       , distinctNormalStateNames
                       , chartLimits = chartLimits@ChartLimits{..}
                       }
  | fst protoFlows < fst flows = Just "the minimum amount of protoFlows must at least match or better even exceed the lower bound of 'normal' flows"
  | snd protoFlows < snd flows = Just "the maximum amount of protoFlows must at least match or better even exceed the upper bound of 'normal' flows"
  | bitwidth < 1 = Just "bitwidth must be greater than 0"
  | fst startNodes < 1 = Just "you likely want to have at least one startNode in the chart"
  | fst regions > 0 && fst regionsStates < 1 = Just "you cannot have Regions when you have no RegionsStates"
  | fst regions < 2 * fst regionsStates = Just "each RegionsState needs at least two Regions"
  | snd regions < 2 * snd regionsStates = Just "each RegionsState needs at least two Regions"
  | fst forkNodes > 0 && fst regionsStates < 1 = Just "you cannot have ForkNodes when you have no RegionsStates"
  | fst joinNodes > 0 && fst regionsStates < 1 = Just "you cannot have JoinNodes when you have no RegionsStates"
  | distinctNormalStateNames && not enforceNormalStateNames = Just "you cannot enforce distinct normal state names without enforcing normal state names"
  | fst totalNodes < fst normalStates + fst hierarchicalStates + fst regionsStates + fst startNodes + fst endNodes + fst forkNodes + fst joinNodes + fst shallowHistoryNodes + fst deepHistoryNodes
  = Just "The minimum total number for Nodes is too small, compared to the other numbers."
  | snd totalNodes < snd normalStates + snd hierarchicalStates + snd regionsStates + snd startNodes + snd endNodes + snd forkNodes + snd joinNodes + snd shallowHistoryNodes + snd deepHistoryNodes
  = Just "The maximum total number for Nodes is too small, compared to the other numbers."
  | otherwise = checkLimits chartLimits

checkLimits :: ChartLimits -> Maybe String
checkLimits ChartLimits{..}
  = checkPair regionsStates "RegionsStates"
    <|> checkPair hierarchicalStates "HierarchicalStates"
    <|> checkPair regions "Regions"
    <|> checkPair normalStates "NormalStates"
    <|> checkPair startNodes "StartNodes"
    <|> checkPair endNodes "EndNodes"
    <|> checkPair forkNodes "ForkNodes"
    <|> checkPair joinNodes "JoinNodes"
    <|> checkPair shallowHistoryNodes "ShallowHistoryNodes"
    <|> checkPair deepHistoryNodes "DeepHistoryNodes"
    <|> checkPair flows "Flows"
    <|> checkPair protoFlows "ProtoFlows"
    <|> checkPair totalNodes "Nodes"
    <|> checkPair componentNames "ComponentNames"
    <|> checkPair triggerNames "TriggerNames"
  where
    checkPair pair name
      | uncurry (>) pair = Just $ "minimum of " ++ name ++ " must be less than or equal to maximum of " ++ name
      | fst pair < 0 = Just $ name ++ " must be greater than or equal to 0"
      | otherwise = Nothing

sdConfigToAlloy :: SDConfig -> String
sdConfigToAlloy  SDConfig { bitwidth
                          , noEmptyTriggers
                          , enforceNormalStateNames
                          , distinctNormalStateNames
                          , noNestedEndNodes
                          , preventMultiEdges
                          , enforceOutgoingEdges
                          , chartLimits = ChartLimits { regionsStates
                                                      , hierarchicalStates
                                                      , regions
                                                      , normalStates
                                                      , componentNames
                                                      , triggerNames
                                                      , startNodes
                                                      , endNodes
                                                      , forkNodes
                                                      , joinNodes
                                                      , shallowHistoryNodes
                                                      , deepHistoryNodes
                                                      , flows
                                                      , protoFlows
                                                      , totalNodes
                                                      }
                          }
  = [i|module GenUMLStateDiagram
      #{componentsSigRules}
      #{trueReachability}
      #{if snd startNodes > 0 then startstateRules else ""}
      #{if snd endNodes > 0 then endstateRules else ""}
      #{if snd regionsStates > 0 then regionRules else ""}
      #{if snd forkNodes + snd joinNodes > 0 then nodeRules else ""}
      #{reachabilityRules}
      #{if snd shallowHistoryNodes + snd deepHistoryNodes > 0 then historyRules else ""}
      #{transitionRules}
      #{substateRules}
      #{nameRules}

// This predicate is automatically generated from the configuration settings within Haskell.
// Please consider that setting a non-exact value to a parameter can cause very slow Alloy execution times.
pred scenarioConfig #{oB}
  #{if enforceNormalStateNames then "no s : NormalStates | no s.name" else ""}
  #{if distinctNormalStateNames then "no disj s1,s2 : NormalStates | s1.name = s2.name" else ""}
  #{if noEmptyTriggers then "EmptyTrigger not in from.States.label" else ""}
  //#{if snd joinNodes >= 1 && snd forkNodes >= 1 then "some (ForkNodes + JoinNodes)" else ""}
  #{maybe "" (\p
                -> (if p then id else \c -> "not (" ++ c ++ ")")
                   "all n1, n2 : Nodes | lone (Flows & from.n1 & to.n2)")
   preventMultiEdges}
  #{if noNestedEndNodes then "EndNodes not in allContainedNodes" else ""}
  #{bounded regions "Regions"}
  #{bounded regionsStates "RegionsStates"}
  #{bounded hierarchicalStates "HierarchicalStates"}
  #{bounded startNodes "StartNodes"}
  #{bounded endNodes "EndNodes"}
  #{bounded shallowHistoryNodes "ShallowHistoryNodes"}
  #{bounded deepHistoryNodes "DeepHistoryNodes"}
  #{bounded normalStates "NormalStates"}
  #{bounded componentNames "ComponentNames"}
  #{bounded triggerNames "TriggerNames"}
  #{bounded forkNodes "ForkNodes"}
  #{bounded joinNodes "JoinNodes"}
  #{bounded flows "Flows"}
  #{bounded protoFlows "ProtoFlows"}
  #{bounded totalNodes "Nodes"}
  #{if enforceOutgoingEdges
    then "all s : States | some (Flows <: from).s"
    else ""}
#{cB}

run scenarioConfig for #{bitwidth} Int,
#{caseExact startNodes "StartNodes"},
#{caseExact endNodes "EndNodes"},
#{caseExact normalStates "NormalStates"},
#{caseExact shallowHistoryNodes "ShallowHistoryNodes"},
#{caseExact deepHistoryNodes "DeepHistoryNodes"},
#{caseExact hierarchicalStates "HierarchicalStates"},
#{caseExact flows "Flows"},
#{caseExact protoFlows "ProtoFlows"},
#{caseExact componentNames "ComponentNames"},
#{caseExact triggerNames "TriggerNames"},
#{caseExact regionsStates "RegionsStates"},
#{caseExact forkNodes "ForkNodes"},
#{caseExact joinNodes "JoinNodes"},
#{caseExact regions "Regions"},
#{caseExact totalNodes "Nodes"}
    |]
  where
  oB = "{"
  cB = "}"
  bounded x entry | uncurry (==) x && fst x == 0 = "no " ++ entry
                  | uncurry (==) x && fst x == 1 = "one " ++ entry
                  | uncurry (<) x && fst x > 0 = "#" ++ entry ++ " >= " ++ show (fst x)
                  | otherwise = ""
  caseExact x entry | uncurry (==) x && fst x == 0 = "0 " ++ entry
                    | uncurry (==) x = "exactly " ++ show (fst x) ++ " " ++ entry
                    | otherwise = show (snd x) ++ " " ++ entry
