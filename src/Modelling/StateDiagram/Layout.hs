{-# LANGUAGE RecordWildCards #-}

module Modelling.StateDiagram.Layout
  ( drawDiagram
  , checkWrapper
  ) where

import Modelling.StateDiagram.Datatype
import Diagrams.Prelude
import Diagrams.Backend.SVG.CmdLine
import qualified Data.Map as Map
import Data.Graph
import Data.Tree
import Data.List.Index
import Modelling.StateDiagram.Arrows
import Modelling.StateDiagram.Support
import Modelling.StateDiagram.Style (Styling(..))
import Data.Hashable (hash)

hashToColour :: Styling -> String -> Colour Double
hashToColour StyledRainbow str =
  let h = hash str
      (gb, r) = h `divMod` 256
      (b, g) = gb `divMod` 256
      r' = fromIntegral r / 255.0
      g' = fromIntegral g / 255.0
      b' = fromIntegral (b `mod` 256) / 255.0
  in sRGB r' g' b'
hashToColour _ _ = black

drawDiagram :: Styling -> UMLStateDiagram String Int -> Diagram B
drawDiagram style = drawWrapper' style [] . orderFunction .
                    unUML (\name substates connections startState -> StateDiagram{label = -1, ..})

textBox :: String -> [String] -> [String]
textBox a stringList
  | length a < 16 = stringList ++ [a] -- set text width here
  | otherwise = textBox (snd splittingText) (stringList ++ [fst splittingText])
    where
      splittingText = splitAt 15 a

drawTextBox :: String -> Colour Double -> Diagram B
drawTextBox s col = text s # font "Monospace" # fontSizeL 0.2 # fc col <> rect (0.11 *
  multiplier) 0.19 # lcA transparent
  where
    multiplier = fromIntegral $ length s

drawText :: String -> Colour Double -> Diagram B
drawText s col = drawing <> rect (width drawing) (height drawing) # lcA transparent
  where
    drawing = vcat (fmap (alignL . flip drawTextBox col) (textBox s [])) # centerXY

drawSwimlane :: Bool -> [Diagram B] -> Double -> [Diagram B]
drawSwimlane False [a, b] c = [a, hrule c # dashingG [0.1] 0 , b] -- vertical AND
drawSwimlane False (x:xs) c = [x, hrule c # dashingG [0.1] 0] ++
  drawSwimlane False xs c
drawSwimlane True [a, b] c = [a, vrule c # dashingG [0.1] 0 , b] -- horizontal AND
drawSwimlane True (x:xs) c = [x, vrule c # dashingG [0.1] 0] ++
  drawSwimlane True xs c
drawSwimlane _ _ _ = []

drawSwimlane' :: [Diagram B] -> Diagram B
drawSwimlane' [a, b] = vcat [a, hrule c, b]
  where
    c = max (width a) (width b)
drawSwimlane' _ = circle 1

appendEdges :: Diagram B -> Double -> RightConnect -> Layout -> Diagram B
appendEdges a 0 _ _ = a
appendEdges a _ NoConnection _ = a
appendEdges a l rightType layouts = case layouts of
  Vertical -> if l > 2 then (a === ((rect w1 l # lcA transparent) <>
    arrowAt' (if rightType == WithArrowhead then arrowStyle1 else arrowStyle2)
    (p2 (0, 0.5 * (-l))) (r2 (0, l)))) # centerXY else a
  _ -> if l > 2 then
    (a ||| ((rect l h1 # lcA transparent) <> arrowAt'
    (if rightType == WithArrowhead then arrowStyle1 else arrowStyle2)
    (p2 (0.5 * l, 0)) (r2 (-l, 0)))) # centerXY else a
  where
    w1 = width a
    h1 = height a

-- jscpd:ignore-start
drawWrapper :: Styling -> [Int] -> Wrapper -> Diagram B
drawWrapper _ a (StartS _ l rightType layouts) = appendEdges (circle 0.1 # fc
  black) l rightType layouts # named (a ++ [-1])
drawWrapper _ a (CrossStateDummy b _) = square 0.005 # fc black # named (a ++ [b])
drawWrapper style a (EndS k l rightType layouts) =
  appendEdges (circle 0.16 # lw ultraThin # lc theColour `atop` circle 0.1 # fc theColour) l rightType layouts
  # named (a ++ [k])
  where
    theColour = hashToColour style (show k)
drawWrapper style a (Leaf b c d l rightType layouts) = if d == "" then appendEdges
  (text' <> roundedRect (width text' + 0.3) (height text' + 0.3) 0.1 # lc theColour) l
  rightType layouts # named (a ++ [b]) else appendEdges drawing'
  l rightType layouts #
  named (a ++ [b])
  where
    text' = drawText c theColour
    text'' = drawText d black
    drawing = drawSwimlane' [text' <> roundedRect (width text' + 0.3) (height text' + 0.3) 0.1
      # lcA transparent, text'' <> roundedRect (width text'' + 0.3) (height text'' + 0.3) 0.1 ] # centerXY
    drawing' = (roundedRect (width drawing) (height drawing) 0.1 # lc theColour <> drawing) #
      centerXY
    theColour = hashToColour style c
drawWrapper _ a (Hist b histType l rightType layouts) = appendEdges ((if
  histType == Deep then drawText "H*" else drawText "H") black <> circle 0.25
  # lc black) l rightType layouts # named (a ++ [b])
drawWrapper _ a (ForkOrJoin b layouts l rightType) = if layouts == Vertical then
  appendEdges (rect 1 0.1 # fc black) l rightType Horizontal # named (a ++
  [b]) else appendEdges (rect 0.1 1 # fc black) l rightType Vertical # named
  (a ++ [b])
drawWrapper _ a (Dummy b Unspecified w) = ((rect w 0.5 # lcA transparent) <>
  arrowAt' arrowStyle2 (p2 (-0.5 * w, 0)) (r2 (w, 0))) # named (a ++ [b])
drawWrapper _ a (Dummy b Horizontal w) = ((rect w 0.5 # lcA transparent) <>
  arrowAt' arrowStyle2 (p2 (-0.5 * w, 0)) (r2 (w, 0))) # named (a ++ [b])
drawWrapper _ a (Dummy b Vertical h) = ((rect 0.5 h # lcA transparent) <>
  arrowAt' arrowStyle2 (p2 (0,-0.5 * h)) (r2 (0, h))) # named (a ++ [b])
drawWrapper _ a (Transition b c l rightType layouts) = appendEdges
  (x <> rect (width x + 0.1) (height x + 0.1) # lcA transparent) l rightType
  layouts # named (a ++ [b])
  where
    x = drawText c black
drawWrapper style a s@AndDecomposition {} = appendEdges (roundedRect (width f) (height f) 0.1 # lc (hashToColour style (head (dropWhile null (map strings (component s)) ++ [""])))
  <> f) (lengthXY s) (rightC s) (outerLayout s) # named (a ++
  [key s])
  where
    w = maximum (fmap (width . drawWrapper style (a ++ [key s])) (component s))
    h = maximum (fmap (height . drawWrapper style (a ++ [key s])) (component s))
    d = (vcat . fmap alignL) (drawSwimlane False (fmap (drawWrapper' style (a ++ [key
      s])) (component s)) w) # centerXY
    e = (hcat . fmap alignT) (drawSwimlane True (fmap (drawWrapper' style (a ++ [key
      s])) (component s)) h) # centerXY
    f = if layout s == Vertical then e else d
drawWrapper style d s@OrDecomposition {} = appendEdges (roundedRect (width draw + 0.9)
  (height draw + 0.9) 0.1 # lc theColour <> text' # alignTL # translate
  (r2 (-0.5 * (width draw + 0.9) + 0.1 , 0.5 * (height draw + 0.9) - 0.1)) <> draw # centerXY) (lengthXY s) (rightC s)
  (outerLayout s) # named (d ++ [key s]) # applyAll (fmap (`drawConnection`
  layout s) connectList)
  where
    text' = drawTextBox (strings s) theColour
    draw = drawLayers style (layout s == Vertical) (d ++ [key s]) (layered s)
    connectList = getConnection (d ++ [key s]) (typedConnections s)
    theColour = hashToColour style (strings s)
-- jscpd:ignore-end

drawWrapper' :: Styling -> [Int] -> Wrapper -> Diagram B
drawWrapper' style d s@OrDecomposition {} = appendEdges (roundedRect (width draw + 0.9)
  (height draw + 0.9) 0.1 # lcA transparent <> alignedText 0 1 (strings s) #
  translate (r2 (-0.485 * (width draw + 0.9), 0.485 * (height draw + 0.9))) #
  fontSize (local 0.2) # fc (hashToColour style (strings s)) <> draw # centerXY) (lengthXY s) (rightC s)
  (outerLayout s) # named (d ++ [key s]) # applyAll (fmap (`drawConnection`
  layout s) connectList)
  where
    draw = drawLayers style (layout s == Vertical) (d ++ [key s]) (layered s)
    connectList = getConnection (d ++ [key s]) (typedConnections s)
drawWrapper' _ _ _ = mempty

drawLayer :: Styling -> Bool -> [Int] -> [Wrapper] -> Diagram B
drawLayer style True prefix layer = vsep 0.5 (fmap (alignL . drawWrapper style prefix)
  layer) # centerXY
drawLayer style False prefix layer = hsep 0.5 (fmap (alignT . drawWrapper style prefix)
  layer) # centerXY

drawLayers :: Styling -> Bool -> [Int] -> [[Wrapper]] -> Diagram B
drawLayers style False prefix layers = hsep 0.5 (fmap (drawLayer style True prefix) layers)
drawLayers style True prefix layers = vsep 0.5 (fmap (drawLayer style False prefix) layers)

drawConnection :: (([Int], [Int]), ConnectionType) -> Layout -> Diagram B ->
  Diagram B
drawConnection (a, ForwardH) Vertical = uncurry downwardArrowWithHead a
drawConnection (a, ForwardH) _ = uncurry forwardArrowWithHead a
drawConnection (a, ForwardWH) Vertical = uncurry downwardArrowWithoutHead a
drawConnection (a, ForwardWH) _ = uncurry forwardArrowWithoutHead a
drawConnection (a, BackwardH) Vertical = uncurry upwardArrowWithHead a
drawConnection (a, BackwardH) _ = uncurry backwardArrowWithHead a
drawConnection (a, BackwardWH) Vertical = uncurry upwardArrowWithoutHead a
drawConnection (a, BackwardWH) _ = uncurry backwardArrowWithoutHead a
drawConnection (a, SelfCL) Vertical = uncurry selfConnect4 a
drawConnection (a, SelfCL) _ = uncurry selfConnect2 a
drawConnection (a, SelfCR) Vertical = uncurry selfConnect3 a
drawConnection (a, SelfCR) _ = uncurry selfConnect1 a

{-
selectSmallerSize :: Wrapper -> Layout -- for OrDecomposition
selectSmallerSize a = if areaH > areaV then Vertical else Horizontal
  where
    v = drawWrapper Unstyled [] (changeLayout a Vertical)
    h = drawWrapper Unstyled [] (changeLayout a Horizontal)
    areaV = width v * height v
    areaH = width h * height h

decideAndLayout :: Wrapper -> Layout
decideAndLayout a = if areaV < areaH then Vertical else Horizontal
  where
    v = AndDecomposition (fmap (`changeAndLayout` Vertical) (component a)) (key a)
      Vertical (lengthXY a) (rightC a) (outerLayout a)
    h = AndDecomposition (fmap (`changeAndLayout` Horizontal) (component a)) (key a)
      Horizontal (lengthXY a) (rightC a) (outerLayout a)
    areaV = width (drawWrapper Unstyled [] v) * height (drawWrapper Unstyled [] v)
    areaH = width (drawWrapper Unstyled [] h) * height (drawWrapper Unstyled [] h)
-}

getWrapper :: StateDiagram String Int [Connection Int] -> Wrapper
getWrapper = toWrapper . localise

toWrapper :: StateDiagram String Int [Connection Int] -> Wrapper
toWrapper (EndState a ) = EndS a 0 NoConnection Unspecified
toWrapper (History a b) = Hist a b 0 NoConnection Unspecified
toWrapper (InnerMostState a b c) = Leaf a b c 0 NoConnection Unspecified
toWrapper (Fork a) = ForkOrJoin a Unspecified 0 NoConnection
toWrapper (Join a) = ForkOrJoin a Unspecified 0 NoConnection
toWrapper s@CombineDiagram {} = AndDecomposition (fmap toWrapper (substates s)) (label
  s) Unspecified 0 NoConnection Unspecified
toWrapper s@StateDiagram {} = OrDecomposition toWrapper' (label s) (name s)
  convertedConnection Unspecified maxKey 0 NoConnection
  Unspecified
  where
    vertexOrder = getOrderedList (substates s)
    mapConnection = mapWithConnection' (substates s) (mapWithConnection
      (filterConnection [] (connections s)))
    graphWithInfo = createGraph mapConnection (substates s) []
    graph = getFirstFromTuple3 graphWithInfo
    getLayers = layering $ dfs graph vertexOrder
    layers = nodeFromVertex getLayers graphWithInfo []
    toWrapper' = if null (startState s) then convertUMLStateDiagramToWrapper
      layers [] else placeStartState (convertUMLStateDiagramToWrapper layers
      []) (startState s)
    newConnection = if null (startState s) then connections s
      else Connection [-1] (startState s) "" : connections s
    convertedConnection = changeConnectionType newConnection toWrapper' []
    maxKey = maximum (Map.keys $ mapWithLabel $ substates s)

createGraph :: Map.Map Int [Int] -> [StateDiagram String Int [Connection Int]] -> [(StateDiagram String Int [Connection Int],
  Int, [Int])] -> (Graph, Vertex -> (StateDiagram String Int [Connection Int], Int, [Int]), Int -> Maybe
  Vertex)
createGraph _ [] a = graphFromEdges a
createGraph c1 (x:xs) a = createGraph c1 xs (a ++ [(x, label
  x, c1 Map.! label x)])

returnNodeFromVertex :: [Int] -> (Graph, Vertex -> (StateDiagram String Int [Connection Int], Int, [Int]
  ), Int -> Maybe Vertex) -> [StateDiagram String Int [Connection Int]] -> [StateDiagram String Int [Connection Int]]
returnNodeFromVertex [] _ a = a
returnNodeFromVertex (x:xs) graphFE listSD = returnNodeFromVertex xs graphFE
  (listSD ++ [getUMLStateDiagram x graphFE])

nodeFromVertex :: [[Int]] -> (Graph, Vertex -> (StateDiagram String Int [Connection Int], Int, [Int]),
  Int -> Maybe Vertex) -> [[StateDiagram String Int [Connection Int]]] -> [[StateDiagram String Int [Connection Int]]]
nodeFromVertex [] _ a = a
nodeFromVertex (x:xs) graphFE listSD = nodeFromVertex xs graphFE (listSD ++
  [returnNodeFromVertex x graphFE []])

layering :: Forest Vertex -> [[Vertex]]
layering = foldl (\ b x -> b ++ levels x) []

convertUMLStateDiagramToWrapper :: [[StateDiagram String Int [Connection Int]]] -> [[Wrapper]] ->
  [[Wrapper]]
convertUMLStateDiagramToWrapper [] x = x
convertUMLStateDiagramToWrapper (x:xs) layers =
  convertUMLStateDiagramToWrapper xs (layers ++ [fmap getWrapper x])

placeStartState :: [[Wrapper]] -> [Int] -> [[Wrapper]]
placeStartState [[a]] _ = [StartS (-1) 0 NoConnection Unspecified] : [[a]]
placeStartState originalW ss =  modifyAt layerToInsert (++ [StartS (-1) 0
  NoConnection Unspecified]) originalW
  where
    ssLayer = findLayer (head ss) originalW 0
    layerToInsert = if ssLayer == (length originalW -1) then ssLayer - 1 else
      ssLayer + 1

addDummy :: Wrapper -> Wrapper
addDummy s@OrDecomposition {} = case layered s of
  [[_]] -> OrDecomposition (fmap (fmap addDummy) (layered s))
    (key s) (strings s) (typedConnections s) (layout s) (maxLabel s) (lengthXY s)
    (rightC s) (outerLayout s)
  _ -> OrDecomposition loopDummy (key s) (strings s)
    connectionWithTransition Unspecified (getSecondFromTuple3 withTransition)
    (lengthXY s) (rightC s) (outerLayout s)
    where
      withDummy = addDummyStates (maxLabel s) (layered s) (typedConnections s) []
      withTransition = addTransitionStates (getSecondFromTuple3 withDummy)
        (buildEmptyWrapperByLayer (getFirstFromTuple3 withDummy) [])
        (getFirstFromTuple3 withDummy) (getThirdFromTuple3 withDummy) []
      stateWithTransition = getFirstFromTuple3 withTransition
      connectionWithTransition = getThirdFromTuple3 withTransition
      {- withTransition = addTransitionStates (maxLabel s) (buildEmptyWrapperByLayer
        (layered s) []) (layered s) (typedConnections s) []
      withDummy = addDummyStates (getSecondFromTuple3 withTransition) (getFirstFromTuple3
        withTransition) (getThirdFromTuple3 withTransition) []
      stateWithDummy = getFirstFromTuple3 withDummy
      connectionWithDummy = getThirdFromTuple3 withDummy -}
      loopDummy = fmap (fmap addDummy) stateWithTransition
addDummy s@AndDecomposition {} = AndDecomposition loopDummy (key s) Unspecified (lengthXY s)
  (rightC s) (outerLayout s)
  where
    loopDummy = fmap addDummy (component s)
addDummy a = a

addD :: ConnectionType -> Int -> [Int] -> [[Wrapper]] -> ConnectWithType ->
  [ConnectWithType] -> ([[Wrapper]], Int, [ConnectWithType])
addD a maxKey [_, _] withDummy c@ConnectWithType {} withConnect = (withDummy,
  maxKey, withConnect ++ [ConnectWithType (Connection [maxKey] (pointTo $
  connecting c) (transition $ connecting c)) a])
addD a maxKey (_:xs) withDummy c@ConnectWithType {} [] =
  addD a (maxKey + 1) xs (modifyAt (head xs) (\ x -> x ++ [Dummy (maxKey + 1)
  Unspecified 0.1]) withDummy) c [ConnectWithType (Connection (pointFrom
  $ connecting c) [maxKey + 1] "") (betweenConnection a)]
addD a maxKey (_:xs) withDummy c@ConnectWithType {} withConnect =
  addD a (maxKey + 1) xs (modifyAt (head xs) (\ x -> x ++ [Dummy (maxKey + 1)
  Unspecified 0.1]) withDummy) c (withConnect ++ [ConnectWithType (
  Connection [maxKey] [maxKey + 1] "") (betweenConnection a)])
addD _ _ _ _ _ _ = ([], 0, [])

addDummyStates :: Int -> [[Wrapper]] -> [ConnectWithType] -> [ConnectWithType]
  -> ([[Wrapper]], Int, [ConnectWithType])
addDummyStates maxKey withDummy [] withConnection = (withDummy, maxKey,
  withConnection)
addDummyStates maxKey withDummy (x:xs) withConnection =
  case (pointFrom (connecting x), pointTo (connecting x)) of
    (a:_, b:_)
      | layerGap == 0 -> addDummyStates maxKey withDummy xs
          (withConnection ++ [x])
      | layerGap == 1 -> addDummyStates maxKey withDummy xs (withConnection
          ++ [x])
      | startLayer > endLayer -> addDummyStates (getSecondFromTuple3 dummy')
          (getFirstFromTuple3 dummy') xs (withConnection ++ getThirdFromTuple3
          dummy')
      | otherwise -> addDummyStates (getSecondFromTuple3 dummy)
          (getFirstFromTuple3 dummy) xs (withConnection ++ getThirdFromTuple3
          dummy)
        where
          startLayer = findLayer a withDummy 0
          endLayer = findLayer b withDummy 0
          layerGap = abs (startLayer - endLayer)
          dummy = addD (connectType x) maxKey [startLayer..endLayer] withDummy
            x []
          dummy' = addD (connectType x) maxKey [startLayer, (startLayer - 1)..
            endLayer]
            withDummy x []
    (_, _) -> addDummyStates maxKey withDummy xs withConnection

addTransitionStates :: Int -> [[Wrapper]] -> [[Wrapper]] -> [ConnectWithType]
  -> [ConnectWithType] -> ([[Wrapper]], Int, [ConnectWithType])
addTransitionStates maxKey transitionLayer originalLayer [] newConnection =
  (combineWrapper originalLayer transitionLayer [], maxKey, newConnection)
addTransitionStates maxKey transitionLayer originalLayer (x:xs) newConnection =
  case connectType x of
    ForwardH -> addTransitionStates k
      (modifyAt startLayer addState transitionLayer)
      originalLayer xs (newConnection ++ [ConnectWithType (Connection
      startLabel [k] "") ForwardWH, ConnectWithType (Connection [k] endLabel
      connectName) ForwardH])
    ForwardWH -> addTransitionStates k
      (modifyAt startLayer addState transitionLayer)
      originalLayer xs (newConnection ++ [ConnectWithType (Connection
      startLabel [k] "") ForwardWH, ConnectWithType (Connection [k] endLabel
      connectName) ForwardWH])
    BackwardWH -> addTransitionStates k
      (modifyAt endLayer addState transitionLayer)
      originalLayer xs (newConnection ++ [ConnectWithType (Connection
      startLabel [k] "") BackwardWH, ConnectWithType (Connection [k] endLabel
      connectName) BackwardWH])
    BackwardH -> addTransitionStates k
      (modifyAt endLayer addState transitionLayer)
      originalLayer xs (newConnection ++ [ConnectWithType (Connection
      startLabel [k] "") BackwardWH, ConnectWithType (Connection [k] endLabel
      connectName) BackwardH])
    _
      | startLabel == endLabel -> if endLayer == length transitionLayer then
          addTransitionStates k (modifyAt (endLayer - 1) addState
          transitionLayer) originalLayer xs (newConnection ++ [ConnectWithType
          (Connection startLabel [k] connectName) SelfCR]) else
          addTransitionStates k (modifyAt endLayer addState transitionLayer)
          originalLayer xs (newConnection ++ [ConnectWithType (Connection
          startLabel [k] connectName) SelfCL])
      | otherwise -> if endLayer == length transitionLayer then
          addTransitionStates k (modifyAt (endLayer - 1) addState
          transitionLayer) originalLayer xs (newConnection ++ type1) else
          addTransitionStates k (modifyAt endLayer addState transitionLayer)
          originalLayer xs (newConnection ++ type2)
  where
    startLayer = findLayer (head $ pointFrom $ connecting x) originalLayer 0
    endLayer = findLayer (head $ pointTo $ connecting x) originalLayer 0
    startLabel = pointFrom $ connecting x
    endLabel = pointTo $ connecting x
    connectName = transition (connecting x)
    addState = if connectName == "" then (++ [Dummy k Unspecified 0.1])
      else (++ [Transition k connectName 0 NoConnection Unspecified])
    k = maxKey + 1
    type1 = case (startLabel, endLabel) of
      ([], []) -> [ConnectWithType (Connection startLabel [k] "") BackwardWH,
        ConnectWithType (Connection [k] endLabel connectName) ForwardH]
      _ -> [ConnectWithType (Connection startLabel [k] "") BackwardWH,
        ConnectWithType (Connection [k] endLabel connectName) ForwardWH]
    type2 = case (startLabel, endLabel) of
      ([], []) -> [ConnectWithType (Connection startLabel [k] "") ForwardWH,
        ConnectWithType (Connection [k] endLabel connectName) BackwardH]
      _ -> [ConnectWithType (Connection startLabel [k] "") ForwardWH,
        ConnectWithType (Connection [k] endLabel connectName) BackwardWH]

connectionsByLayers :: [ConnectWithType] -> [[Wrapper]] -> [[ConnectWithType]]
  -> [[ConnectWithType]]
connectionsByLayers [] _ connectionLayers = connectionLayers
connectionsByLayers (x:xs) layers connectionLayers =
  case (pointFrom (connecting x), pointTo (connecting x)) of
    (a:_, b:_)
      | startLayer > endLayer -> connectionsByLayers xs layers (modifyAt
          endLayer (++ [x]) connectionLayers)
      | otherwise -> connectionsByLayers xs layers (modifyAt startLayer (++ [x]
          ) connectionLayers)
        where
          startLayer = findLayer a layers 0
          endLayer = findLayer b layers 0
    (_, _) -> connectionsByLayers xs layers connectionLayers

startStateFirst :: StateDiagram String Int [Connection Int] -> [Int] -> StateDiagram String Int [Connection Int]
startStateFirst a [] = a
startStateFirst a@StateDiagram {} (x:xs) =
  StateDiagram (loopOrder : tail newOrder) (label a) (name a) (connections a)
  (startState a)
  where
    newOrder = moveToFirst (substates a) x []
    loopOrder = startStateFirst (head newOrder) xs
startStateFirst a@CombineDiagram {} (x:xs) =
  CombineDiagram (loopOrder : tail newOrder) (label a)
  where
    newOrder = moveToFirst (substates a) x []
    loopOrder = startStateFirst (head newOrder) xs
startStateFirst a _ = a

rearrangeSubstates :: StateDiagram String Int [Connection Int] -> StateDiagram String Int [Connection Int]
rearrangeSubstates s@StateDiagram {} = case startState s of
  [] -> StateDiagram (fmap rearrangeSubstates (substates s)) (label s) (name s)
    (connections s) (startState s)
  _ -> StateDiagram (fmap rearrangeSubstates (substates n)) (label n) (name s)
    (connections n) (startState n)
  where
    n = startStateFirst s (startState s)
rearrangeSubstates s@CombineDiagram {} =
  CombineDiagram (fmap rearrangeSubstates (substates s)) (label s)
rearrangeSubstates a = a

{-
changeLayout :: Wrapper -> Layout -> Wrapper
changeLayout s@OrDecomposition {} a = OrDecomposition (layered s) (key s) (strings s)
  (typedConnections s) a (maxLabel s) (lengthXY s) (rightC s)
  (outerLayout s)
changeLayout s _ = s

changeOrLayout :: Wrapper -> Layout -> Wrapper
changeOrLayout s@OrDecomposition {} b = case layered s of
  [[a@AndDecomposition {}]] -> OrDecomposition (layered s) (key s) (strings s) (typedConnections s)
    (layout a) (maxLabel s) (lengthXY s) (rightC s) b
  _ -> OrDecomposition (layered s) (key s) (strings s) (typedConnections s)
    (layout s) (maxLabel s) (lengthXY s) (rightC s) b
changeOrLayout s@ForkOrJoin {} a = ForkOrJoin (key s) a (lengthXY s) (rightC s)
changeOrLayout s@Dummy {} a = Dummy (key s) a (lengthXY s)
changeOrLayout s@AndDecomposition {} a = AndDecomposition (component s) (key s) (layout s)
  (lengthXY s) (rightC s) a
changeOrLayout s@Hist {} a = Hist (key s) (history s) (lengthXY s)
  (rightC s) a
changeOrLayout s@EndS {} a = EndS (key s) (lengthXY s) (rightC s) a
changeOrLayout s@Leaf {} a = Leaf (key s) (strings s) (operation s) (lengthXY s
  ) (rightC s) a
changeOrLayout s@StartS {} a = StartS (key s) (lengthXY s) (rightC s) a
changeOrLayout s@Transition {} a = Transition (key s) (transitionName s)
  (lengthXY s) (rightC s) a
changeOrLayout s@CrossStateDummy {} _ = s

changeAndLayout :: Wrapper -> Layout -> Wrapper
changeAndLayout a b = if layout a == b then a else
  case layered a of
    [[s@AndDecomposition {}]] -> OrDecomposition [[AndDecomposition (fmap (`changeAndLayout` b)
      (component s)) (key s) b (lengthXY s) (rightC s) b]]
      (key a) (strings a) (typedConnections a) b (maxLabel a) (lengthXY a)
      (rightC a) (outerLayout a)
    _ -> OrDecomposition (fmap (fmap (`changeOrLayout` b)) (layered a)) (key a)
      (strings a) (typedConnections a) b (maxLabel a) (lengthXY a)
      (rightC a) b

assignLayout :: Wrapper -> Wrapper
assignLayout s@OrDecomposition {} = if checkOrList (concat (layered s)) then
  newOrLayout else OrDecomposition newLayered (key s) (strings s) (typedConnections s)
  (selectSmallerSize s) (maxLabel s) (lengthXY s) (rightC s)
  (outerLayout s)
  where
    newLayered = fmap (fmap (`changeOrLayout` selectSmallerSize s)) (layered s)
    newOr = OrDecomposition (fmap (fmap assignLayout) (layered s)) (key s) (strings s)
      (typedConnections s) (layout s) (maxLabel s) (lengthXY s) (rightC s)
      (outerLayout s)
    newOrLayout = OrDecomposition (fmap (fmap (`changeOrLayout` selectSmallerSize newOr
      )) (layered newOr)) (key s) (strings s) (typedConnections s)
      (selectSmallerSize newOr) (maxLabel s) (lengthXY s) (rightC s)
      (outerLayout s)
assignLayout s@AndDecomposition {} = AndDecomposition (fmap (`changeAndLayout` decidedLayout)
  newLayered) (key s) decidedLayout (lengthXY s) (rightC s)
  (outerLayout s)
  where
    newLayered = fmap assignLayout (component s)
    decidedLayout = decideAndLayout (AndDecomposition newLayered (key s) Unspecified
      (lengthXY s) (rightC s) (outerLayout s))
assignLayout a = a
-}

reduceCrossStateCrossing :: Wrapper -> Wrapper
reduceCrossStateCrossing s@OrDecomposition {} = if null (fst dummyToAdd) then OrDecomposition
  (fmap (fmap reduceCrossStateCrossing) (layered s)) (key s) (strings s)
  (typedConnections s) (layout s) (maxLabel s) (lengthXY s) (rightC s)
  (outerLayout s) else OrDecomposition (fmap (fmap reduceCrossStateCrossing) (layered
  addingDummy)) (key s) (strings s) (typedConnections addingDummy) (layout s)
  (maxLabel addingDummy) (lengthXY s) (rightC s) (outerLayout s)
  where
    dummyToAdd = filterCrossStateConnection (typedConnections s) [] []
    newOr = OrDecomposition (layered s) (key s) (strings s) (snd dummyToAdd)
      Unspecified (maxLabel s) (lengthXY s) (rightC s) (outerLayout
      s)
    addingDummy = foldl addCrossSuperStateDummy newOr (fst dummyToAdd)
reduceCrossStateCrossing s@AndDecomposition {} = AndDecomposition (fmap
  reduceCrossStateCrossing (component s)) (key s) (layout s) (lengthXY s)
  (rightC s) (outerLayout s)
reduceCrossStateCrossing a = a

reduceCrossStateCrossing' :: Wrapper -> Wrapper
reduceCrossStateCrossing' s@OrDecomposition {} = if null (fst dummyToAdd) then OrDecomposition
  (fmap (fmap reduceCrossStateCrossing') (layered s)) (key s) (strings s)
  (typedConnections s) (layout s) (maxLabel s) (lengthXY s) (rightC s)
  (outerLayout s) else addingDummy
  where
    dummyToAdd = filterCrossStateConnection (typedConnections s) [] []
    newOr = OrDecomposition (fmap (fmap reduceCrossStateCrossing') (layered s)) (key s)
      (strings s) (snd dummyToAdd) (layout s) (maxLabel s) (lengthXY s)
      (rightC s) (outerLayout s)
    addingDummy = foldl addCrossSuperStateDummy newOr (fst dummyToAdd)
reduceCrossStateCrossing' s@AndDecomposition {} = AndDecomposition (fmap
  reduceCrossStateCrossing (component s)) (key s) (layout s) (lengthXY s)
  (rightC s) (outerLayout s)
reduceCrossStateCrossing' a = a

addCrossSuperStateDummy :: Wrapper -> ConnectWithType -> Wrapper
addCrossSuperStateDummy a b = case (pointFrom $ connecting b, pointTo $
  connecting b) of
  -- start > end = addDummyRight BackwardH | start < end = addDummyLeft ForwardH | start == end = if start == length - 1 then addDummyLeft ForwardH else addDummyRight BackwardH
  ([_], _:_:_)  -- pointFrom outside to inside
    | startLayer > endLayer -> addDummyRight' BackwardH endPoint
        [ConnectWithType (Connection startPoint pointToLabel connectionName)
        BackwardWH] a
    | startLayer < endLayer -> addDummyLeft' ForwardH endPoint
        [ConnectWithType (Connection startPoint pointToLabel connectionName)
        ForwardWH] a
    | otherwise -> if startLayer == length (layered a) - 1 then addDummyLeft'
        ForwardH endPoint [ConnectWithType (Connection startPoint pointToLabel
        connectionName) SelfCL] a else addDummyRight' BackwardH endPoint
        [ConnectWithType (Connection startPoint pointToLabel connectionName)
        SelfCL] a
  -- start > end = addDummyLeft BackwardWH | start < end = addDummyRight ForwardWH | start == end = if start == length - 1 then addDummyLeft BackwardWH else addDummyRight ForwardWH
  (_:_:_, [_])  -- pointFrom inside to outside
    | startLayer > endLayer -> addDummyLeft' BackwardWH startPoint
        [ConnectWithType (Connection pointFromLabel endPoint connectionName)
        BackwardH] a
    | startLayer < endLayer -> addDummyRight' ForwardWH startPoint
        [ConnectWithType (Connection pointFromLabel endPoint connectionName)
        ForwardH] a
    | otherwise -> if startLayer == length (layered a) - 1 then addDummyLeft'
        BackwardWH startPoint [ConnectWithType (Connection pointFromLabel
        endPoint connectionName) SelfCL] a else addDummyRight'
        ForwardWH startPoint [ConnectWithType (Connection pointFromLabel
        endPoint connectionName) SelfCL] a
  -- combine first 2 cases
  (_, _)
    | startLayer > endLayer -> addDummyRight' BackwardH endPoint []
        (addDummyLeft' BackwardWH startPoint [ConnectWithType (Connection
        pointFromLabel pointToLabel connectionName) BackwardWH] a)
    | startLayer < endLayer -> addDummyLeft' ForwardH endPoint []
        (addDummyRight' ForwardWH startPoint [ConnectWithType (Connection
        pointFromLabel pointToLabel connectionName) ForwardWH] a)
    | otherwise -> if startLayer == length (layered a) - 1 then addDummyLeft'
        ForwardH endPoint [] (addDummyLeft' BackwardWH startPoint
        [ConnectWithType (Connection pointFromLabel pointToLabel connectionName
        ) SelfCL] a) else addDummyRight' BackwardH endPoint [] (addDummyRight'
         ForwardWH startPoint [ConnectWithType (Connection pointFromLabel
         pointToLabel connectionName) SelfCL] a)
  where
    startLayer = findLayer (head $ pointFrom $ connecting b) (layered a) 0
    endLayer = findLayer (head $ pointTo $ connecting b) (layered a) 0
    startPoint = pointFrom $ connecting b
    endPoint = pointTo $ connecting b
    connectionName = transition $ connecting b
    pointFromLabel = getDeeperConnection (pointFrom $ connecting b) a
    pointToLabel = getDeeperConnection (pointTo $ connecting b) a

-- jscpd:ignore-start
-- cType = original connectType -- connectWT = between, therefore always without head
addDummyLeft' :: ConnectionType -> [Int] -> [ConnectWithType]  -> Wrapper ->
  Wrapper
addDummyLeft' cType (x:xs) connectWT a = OrDecomposition loop (key a) (strings a) (
  connectWT ++ typedConnections a) Unspecified (maxLabel a) (lengthXY a)
  (rightC a) (outerLayout a)
  where
    loop = fmap (fmap (addDummyLeft cType xs x)) (layered a)
addDummyLeft' _ _ _ _ = StartS (-1) 0 NoConnection Unspecified
-- jscpd:ignore-end

-- cType = original connectType -- connectWT = between, therefore always without head
addDummyRight' :: ConnectionType -> [Int] -> [ConnectWithType]  -> Wrapper ->
  Wrapper
addDummyRight' cType (x:xs) connectWT a = OrDecomposition loop (key a) (strings a) (
  connectWT ++ typedConnections a) Unspecified (maxLabel a) (lengthXY a)
  (rightC a) (outerLayout a)
  where
    loop = fmap (fmap (addDummyRight cType xs x)) (layered a)
addDummyRight' _ _ _ _ = StartS (-1) 0 NoConnection Unspecified

addDummyLeft :: ConnectionType -> [Int] -> Int -> Wrapper -> Wrapper
addDummyLeft ForwardH [a] matchLabel b = if key b == matchLabel then
  OrDecomposition (insertDummyLeft b) (key b) (strings b) (
  ConnectWithType (Connection [maxLabel b + 1] [a] "") ForwardH : typedConnections
  b) Unspecified (maxLabel b + 1) (lengthXY b) (rightC b)
  (outerLayout b) else b
addDummyLeft ForwardH (x:xs) matchLabel b@OrDecomposition {} = if key b == matchLabel
  then OrDecomposition (fmap (fmap (addDummyLeft ForwardH xs x)) (
  insertDummyLeft b)) (key b) (strings b) (ConnectWithType (Connection [
  maxLabel b + 1] (getDeeperConnection (x:xs) b) "") ForwardWH : typedConnections b)
  Unspecified (maxLabel b + 1) (lengthXY b) (rightC b) (outerLayout
  b) else b
addDummyLeft ForwardH (x:xs) matchLabel b@AndDecomposition {} = if key b == matchLabel
  then AndDecomposition (fmap (addDummyLeft ForwardH xs x) (component b)) (key b) (
  layout b) (lengthXY b) (rightC b) (outerLayout b) else b
addDummyLeft BackwardWH [a] matchLabel b = if key b == matchLabel then
  OrDecomposition (insertDummyLeft b) (key b) (strings b) (
  ConnectWithType (Connection [a] [maxLabel b + 1] "") BackwardWH : typedConnections
  b) Unspecified (maxLabel b + 1) (lengthXY b) (rightC b) (outerLayout b) else b
addDummyLeft BackwardWH (x:xs) matchLabel b@OrDecomposition {} = if key b == matchLabel
  then OrDecomposition (fmap (fmap (addDummyLeft BackwardWH xs x)) (
  insertDummyLeft b)) (key b) (strings b) (ConnectWithType (Connection (
  getDeeperConnection (x:xs) b) [maxLabel b + 1] "") BackwardWH : typedConnections b
  ) Unspecified (maxLabel b + 1) (lengthXY b) (rightC b) (
  outerLayout b) else b
addDummyLeft BackwardWH (x:xs) matchLabel b@AndDecomposition {} = if key b ==
  matchLabel then AndDecomposition (fmap (addDummyLeft BackwardWH xs x) (component b))
  (key b) (layout b) (lengthXY b) (rightC b) (outerLayout b) else b
addDummyLeft _ _ _ b = b

addDummyRight :: ConnectionType -> [Int] -> Int -> Wrapper -> Wrapper
addDummyRight BackwardH [a] matchLabel b = if key b == matchLabel then
  OrDecomposition (insertDummyRight b) (key b) (strings b) (
  ConnectWithType (Connection [maxLabel b + 1] [a] "") BackwardH : typedConnections
  b) Unspecified (maxLabel b + 1) (lengthXY b) (rightC b)
  (outerLayout b) else b
addDummyRight BackwardH (x:xs) matchLabel b@OrDecomposition {} = if key b == matchLabel
  then OrDecomposition (fmap (fmap (addDummyRight BackwardH xs x)) (
  insertDummyRight b)) (key b) (strings b) (ConnectWithType (Connection [
  maxLabel b + 1] (getDeeperConnection (x:xs) b) "") BackwardWH : typedConnections b
  ) Unspecified (maxLabel b + 1) (lengthXY b) (rightC b)
  (outerLayout b) else b
addDummyRight BackwardH (x:xs) matchLabel b@AndDecomposition {} = if key b ==
  matchLabel then AndDecomposition (fmap (addDummyRight BackwardH xs x) (component b))
  (key b) (layout b) (lengthXY b) (rightC b) (outerLayout b) else b
addDummyRight ForwardWH [a] matchLabel b = if key b == matchLabel then
  OrDecomposition (insertDummyRight b) (key b) (strings b) (
  ConnectWithType (Connection [a] [maxLabel b + 1] "") ForwardWH : typedConnections
  b) Unspecified (maxLabel b + 1) (lengthXY b) (rightC b)
  (outerLayout b) else b
addDummyRight ForwardWH (x:xs) matchLabel b@OrDecomposition {} = if key b == matchLabel
  then OrDecomposition (fmap (fmap (addDummyRight ForwardWH xs x)) (
  insertDummyRight b)) (key b) (strings b) (ConnectWithType (Connection (
  getDeeperConnection (x:xs) b) [maxLabel b + 1] "") ForwardWH : typedConnections b)
  Unspecified (maxLabel b + 1) (lengthXY b) (rightC b) (outerLayout
  b) else b
addDummyRight ForwardWH (x:xs) matchLabel b@AndDecomposition {} = if key b ==
  matchLabel then AndDecomposition (fmap (addDummyRight ForwardWH xs x) (component b))
  (key b) (layout b) (lengthXY b) (rightC b) (outerLayout b) else b
addDummyRight _ _ _ b = b


-- | 'lengthXY' of 'CrossStateDummy'
csdWidth :: Double
csdWidth = 0.05

insertDummyLeft :: Wrapper  -> [[Wrapper]]
insertDummyLeft a = if all checkWrapperLayer (head $ layered a) then
  (CrossStateDummy (maxLabel a + 1) csdWidth : head (layered a)) : tail (layered a)
  else [CrossStateDummy (maxLabel a + 1) csdWidth] : layered a

insertDummyRight :: Wrapper -> [[Wrapper]]
insertDummyRight a = if all checkWrapperLayer (last $ layered a) then init (
  layered a) ++ [last (layered a) ++ [CrossStateDummy (maxLabel a + 1) csdWidth]] else
  layered a ++ [[CrossStateDummy (maxLabel a + 1) csdWidth]]

changeConnectionType :: [Connection Int] -> [[Wrapper]] -> [ConnectWithType]
  -> [ConnectWithType]
changeConnectionType [] _ withType = withType
changeConnectionType (x:xs) layers withType = changeConnectionType xs layers
  (withType ++ [ConnectWithType x decideType])
  where
    startLayer = findLayer (head $ pointFrom x) layers 0
    endLayer = findLayer (head $ pointTo x) layers 0
    decideType = decideConnectionType startLayer endLayer

changeRightConnection :: Wrapper -> RightConnect -> Wrapper
changeRightConnection s@OrDecomposition {} a = OrDecomposition (layered s) (key s) (strings s)
  (typedConnections s) (layout s) (maxLabel s) (lengthXY s) a
  (outerLayout s)
changeRightConnection s@AndDecomposition {} a = AndDecomposition (component s) (key s) (layout
  s) (lengthXY s) a (outerLayout s)
changeRightConnection s@EndS {} a = EndS (key s) (lengthXY s) a (outerLayout s)
changeRightConnection s@ForkOrJoin {} a = ForkOrJoin (key s) (outerLayout s) (lengthXY s) a
changeRightConnection s@Hist {} a = Hist (key s) (history s) (lengthXY s) a
  (outerLayout s)
changeRightConnection s@Leaf {} a = Leaf (key s) (strings s) (operation s)
  (lengthXY s) a (outerLayout s)
changeRightConnection s@StartS {} a = StartS (key s) (lengthXY s) a
  (outerLayout s)
changeRightConnection s@CrossStateDummy {} _ = s
changeRightConnection s@Dummy {} _ = s
changeRightConnection s@Transition {} a = Transition (key s) (transitionName s)
  (lengthXY s) a (outerLayout s)

changeRightConnection' :: RightConnect -> RightConnect -> RightConnect
changeRightConnection' originalRight toChangeRight =
  case (originalRight, toChangeRight) of
    (NoConnection, _) -> toChangeRight
    (WithoutArrowhead, WithoutArrowhead) -> WithoutArrowhead
    (WithoutArrowhead, WithArrowhead) -> WithArrowhead
    (WithArrowhead, _) -> WithArrowhead
    (_, _) -> NoConnection

changeRightConnections :: [Int] -> Int -> RightConnect -> Wrapper -> Wrapper
changeRightConnections [] matchLabel rightType s = if key s == matchLabel then
  changeRightConnection s (changeRightConnection' (rightC s) rightType) else
  s
changeRightConnections (x:xs) matchLabel rightType s@OrDecomposition {} = if key s ==
  matchLabel then OrDecomposition (fmap (fmap (changeRightConnections xs x rightType))
  (layered s)) (key s) (strings s) (typedConnections s) (layout s) (maxLabel s)
  (lengthXY s) (rightC s) (outerLayout s) else s
changeRightConnections (x:xs) matchLabel rightType s@AndDecomposition {} = if key s ==
  matchLabel then AndDecomposition (fmap (changeRightConnections xs x rightType)
  (component s)) (key s) (layout s) (lengthXY s) (rightC s)
  (outerLayout s) else s
changeRightConnections _ _ _ s = s

markRightConnection :: Wrapper -> ConnectWithType -> Wrapper
markRightConnection a b = OrDecomposition (layered afterChange) (key a) (strings a)
  (typedConnections a ++ [ConnectWithType (connecting b) decideConnectType]) (layout
  a) (maxLabel a) (lengthXY a) (rightC a) (outerLayout a)
  where
    startLayer = findLayer (head (pointFrom $ connecting b)) (layered a) 0
    endLayer = findLayer (head (pointTo $ connecting b)) (layered a) 0
    stateToModify = if startLayer < endLayer then pointFrom $ connecting b else
      pointTo $ connecting b
    afterChange = changeRightConnections stateToModify (key a) (if connectType
      b == BackwardH then WithArrowhead else WithoutArrowhead) a -- changing right connection data
    deeperState = getDeeperState a stateToModify
    decideConnectType = if (connectType b == BackwardH) && (lengthXY deeperState > 2)
      then BackwardWH else connectType b

modifyRightConnection :: Wrapper -> Wrapper
modifyRightConnection s@OrDecomposition {} = OrDecomposition (fmap (fmap modifyRightConnection)
  (layered newOr)) (key s) (strings s) (typedConnections newOr) (layout s)
  (maxLabel s) (lengthXY s) (rightC s) (outerLayout s)
  where
    dummyOr = OrDecomposition (layered s) (key s) (strings s) [] (layout s)
      (maxLabel s) (lengthXY s) (rightC s) (outerLayout s)
    newOr = foldl markRightConnection dummyOr (typedConnections s)
modifyRightConnection s@AndDecomposition {} = AndDecomposition (fmap modifyRightConnection
  (component s)) (key s) (layout s) (lengthXY s) (rightC s)
  (outerLayout s)
modifyRightConnection s = s

changeLength :: Double -> Wrapper -> Wrapper
changeLength l s = case s of
  OrDecomposition {}
    | outerLayout s == Vertical -> OrDecomposition (layered s) (key s) (strings s)
        (typedConnections s) (layout s) (maxLabel s) (l - h) (rightC s)
        (outerLayout s)
    | otherwise -> OrDecomposition (layered s) (key s) (strings s)
        (typedConnections s) (layout s) (maxLabel s) (l - w) (rightC s)
        (outerLayout s)
  EndS {}
    | outerLayout s == Vertical ->
        EndS (key s) (l - h) (rightC s) (outerLayout s)
    | otherwise ->
        EndS (key s) (l - w) (rightC s) (outerLayout s)
  AndDecomposition {}
    | outerLayout s == Vertical -> AndDecomposition (component s) (key s)
        (layout s) (l - h) (rightC s) (outerLayout s)
    | otherwise -> AndDecomposition (component s) (key s)
        (layout s) (l - w) (rightC s) (outerLayout s)
  Leaf {}
    | outerLayout s == Vertical -> Leaf (key s) (strings s) (operation s)
        (l - h) (rightC s) (outerLayout s)
    | otherwise -> Leaf (key s) (strings s) (operation s)
        (l - w) (rightC s) (outerLayout s)
  Hist {}
    | outerLayout s == Vertical -> Hist (key s) (history s)
        (l - h) (rightC s) (outerLayout s)
    | otherwise -> Hist (key s) (history s) (l - w) (rightC s) (outerLayout s)
  CrossStateDummy {} -> s
  Dummy {}
    | outerLayout s == Vertical -> Dummy (key s) (outerLayout s) l
    | otherwise -> Dummy (key s) (outerLayout s) l
  Transition {}
    | outerLayout s == Vertical -> Transition (key s) (transitionName s)
        (l - h) (rightC s) (outerLayout s)
    | otherwise -> Transition (key s) (transitionName s)
        (l - w) (rightC s) (outerLayout s)
  ForkOrJoin {}
    | outerLayout s == Vertical -> ForkOrJoin (key s) (outerLayout s)
        (l - h) (rightC s)
    | otherwise -> ForkOrJoin (key s) (outerLayout s) (l - w) (rightC s)
  StartS {}
    | outerLayout s == Vertical -> StartS (key s) (l - h) (rightC s)
        (outerLayout s)
    | otherwise -> StartS (key s) (l - w) (rightC s) (outerLayout s)
  where
    w = width (drawWrapper Unstyled [] s)
    h = height (drawWrapper Unstyled [] s)

assignLayerLength :: Layout -> [Wrapper] -> [Wrapper]
assignLayerLength layouts a = if layouts == Vertical then
  fmap (changeLength maxHeight) a else
  fmap (changeLength maxWidth) a
  where
    maxWidth = width (drawLayer Unstyled True [] a)
    maxHeight = height (drawLayer Unstyled False [] a)

assignLength :: Wrapper -> Wrapper
assignLength s@OrDecomposition {} = OrDecomposition newLayered (key s) (strings s)
      (typedConnections s) (layout s) (maxLabel s) (lengthXY s) (rightC s
      ) (outerLayout s)
  where
    loop = OrDecomposition (fmap (fmap assignLength) (layered s)) (key s) (strings s)
      (typedConnections s) (layout s) (maxLabel s) (lengthXY s) (rightC s
      ) (outerLayout s)
    newLayered = fmap (assignLayerLength (layout s)) (layered loop)
assignLength s@AndDecomposition {} = AndDecomposition (fmap assignLength (component s)) (key s)
  (layout s) (lengthXY s) (rightC s) (outerLayout s)
assignLength s = s

orderFunction :: StateDiagram String Int [Connection Int] -> Wrapper
orderFunction a = loopEdgeRed 5 $
  modifyRightConnection $ assignLength $
  addDummy $
  reduceCrossStateCrossing' $ getWrapper $ rearrangeSubstates a

edgeCrossingReduc :: Wrapper -> Wrapper
edgeCrossingReduc s@OrDecomposition {} = case layered s of
  [[_]] -> OrDecomposition (fmap (fmap edgeCrossingReduc) (layered s)) (key s) (strings
    s) (typedConnections s) (layout s) (maxLabel s) (lengthXY s) (rightC
    s) (outerLayout s)
  _ -> OrDecomposition withEdgeReduc (key s) (strings s) (typedConnections s) (layout s)
    (maxLabel s) (lengthXY s) (rightC s) (outerLayout s)
    where
      loopDummy = fmap (fmap edgeCrossingReduc) (layered s)
      withEdgeReduc = edgeRedLayers [] loopDummy []
        (connectionsByLayers (typedConnections s) loopDummy
        (buildEmptyConnectionByLayer loopDummy [])) 0 0 True

edgeCrossingReduc s@AndDecomposition {} = AndDecomposition (fmap edgeCrossingReduc (component
  s)) (key s) (layout s) (lengthXY s) (rightC s) (outerLayout s)
edgeCrossingReduc s = s

loopEdgeRed :: Int -> Wrapper -> Wrapper
loopEdgeRed 0 s = s
loopEdgeRed loop s = loopEdgeRed (loop - 1) (edgeCrossingReduc s)

edgeRedLayer :: [Wrapper] -> [Wrapper] -> [ConnectWithType] -> [Wrapper] ->
   Bool -> ([Wrapper], Int)
edgeRedLayer _ [] _ _ _ = ([], 0)
edgeRedLayer layerBef [a] connectionList layerAf checkType =
  (layerAf ++ [a], toAdd2 + toAdd)
  where
    toAdd = addCrossing layerBef (layerAf ++ [a]) connectionList checkType 0
    toAdd2 = addCrossing2 layerBef (layerAf ++ [a]) connectionList checkType 0
edgeRedLayer layerBef (a:b:xs) connectionList layerAf checkType
  | crossingNo1 > crossingNo2 = edgeRedLayer layerBef (a:xs) connectionList
      (layerAf ++ [b]) checkType
  | otherwise = edgeRedLayer layerBef (b:xs) connectionList (layerAf ++ [a])
      checkType
    where
      getListLayerBef1 = getConnectionWithLayerBefore2 a connectionList []
      getListLayerBef2 = getConnectionWithLayerBefore2 b connectionList []
      crossingNo1 = sum [higherIndex2 (x, y) layerBef checkType | x <-
        getListLayerBef1, y <- getListLayerBef2]
      crossingNo2 = sum [higherIndex2 (y, x) layerBef checkType | x <-
        getListLayerBef1, y <- getListLayerBef2]

edgeRedLayers :: [[Wrapper]] -> [[Wrapper]] -> [[Wrapper]] ->
  [[ConnectWithType]] -> Int -> Int -> Bool -> [[Wrapper]]
edgeRedLayers layersBefore [] layersAfter connectionList crossingBef
  crossingAfter loop
  | null layersBefore = edgeRedLayers layersAfter (reverse layersAfter) []
      (reverse connectionList) crossingAfter 0 (not loop) -- first run
  | crossingAfter < crossingBef = edgeRedLayers layersAfter (reverse
      layersAfter) [] (reverse connectionList) crossingAfter 0 (not loop)
  | otherwise = if loop then reverse layersBefore else layersBefore
edgeRedLayers layersBefore (x:xs) [] connectionList crossingBef crossingAfter
  loop = edgeRedLayers layersBefore xs [x] connectionList crossingBef
  crossingAfter loop
edgeRedLayers layersBefore (x:xs) layersAfter connectionList crossingBef
  crossingAfter loop = edgeRedLayers layersBefore xs (layersAfter ++ [fst
  modifiedLayer]) connectionList  crossingBef (crossingAfter + snd
  modifiedLayer) loop
  where
    wrapperToInt = last layersAfter
    modifiedLayer = edgeRedLayer wrapperToInt x (connectionList !! (length
      layersAfter - 1)) [] loop

countCrossStateCrossing :: [Int] -> [[Int]] -> [ConnectWithType] -> Int -> Int
countCrossStateCrossing _ [_] _ totalCrossing = totalCrossing
countCrossStateCrossing layerBef (a:b:xs) connectionList totalCrossing =
  countCrossStateCrossing layerBef (b:xs) connectionList (totalCrossing +
  crossingNo)
  where
    getListLayerBef1 = getConnectionWithLayerBefore3 a connectionList []
    getListLayerBef2 = getConnectionWithLayerBefore3 b connectionList []
    crossingNo = sum [higherIndex (x, y) layerBef | [x] <- getListLayerBef1,
      [y] <- getListLayerBef2]
countCrossStateCrossing _ _ _ _ = 0

addCrossing :: [Wrapper] -> [Wrapper] -> [ConnectWithType] -> Bool -> Int ->
  Int
addCrossing _ [] _ _ totalCrossing = totalCrossing
addCrossing layerBef (x:xs) connectionList checkType totalCrossing =
  case x of
    OrDecomposition {} -> addCrossing layerBef xs connectionList checkType
      (totalCrossing + addCrossingNo)
    AndDecomposition {} -> addCrossing layerBef xs connectionList checkType
      (totalCrossing + addCrossingNo)
    _ -> addCrossing layerBef xs connectionList checkType totalCrossing
  where
    compareList = getCompareList checkType x
    addCrossingNo = countCrossStateCrossing (fmap key layerBef) compareList
      connectionList 0

addCrossing2 :: [Wrapper] -> [Wrapper] -> [ConnectWithType] -> Bool -> Int -> Int
addCrossing2 _ [_] _ _ totalCrossing = totalCrossing
addCrossing2 layerBef (a:xs) connectionList checkType totalCrossing =
  addCrossing2 layerBef xs connectionList checkType (totalCrossing + newCrossing)
  where
    newCrossing = addCrossing2' layerBef a xs connectionList checkType 0
addCrossing2 _ _ _ _ _ = 0

addCrossing2' :: [Wrapper] -> Wrapper -> [Wrapper] -> [ConnectWithType] -> Bool -> Int -> Int
addCrossing2' _ _ [] _ _ totalCrossing = totalCrossing
addCrossing2' layerBef fixedWrapper (b:xs) connectionList checkType totalCrossing =
  addCrossing2' layerBef fixedWrapper xs connectionList checkType (totalCrossing + crossingNo)
  where
    getListLayerBef1 = getConnectionWithLayerBefore2 fixedWrapper connectionList []
    getListLayerBef2 = getConnectionWithLayerBefore2 b connectionList []
    crossingNo = sum [higherIndex2 (x, y) layerBef checkType | x <-
      getListLayerBef1, y <- getListLayerBef2]

--checkWrapper
checkWrapper :: StateDiagram String Int [Connection Int] -> Maybe String
checkWrapper a
  | not (checkOuterMostWrapper b) = Just ("Error: Outermost layer must be "
    ++ "'OrDecomposition' constructor")
  | not (checkOrDecompositionSubstates b) = Just ("Error: Substates of OrDecomposition "
    ++ "constructor cannot be empty or just Hist/ForkOrJoin/StartS/Dummy/Transition")
  | not (checkAndDecompositionSubstates b) = Just ("Error: AndDecomposition constructor must "
    ++ "contain at least 2 OrDecomposition and no other type of constructor")
  | not (checkLayout b) = Just ("Error: Horizontal slicing must be followed by "
    ++ "vertical layering or vise versa")
  | otherwise = Nothing
    where
      b = addDummy $ getWrapper $ rearrangeSubstates a

checkOuterMostWrapper :: Wrapper -> Bool
checkOuterMostWrapper OrDecomposition {} = True
checkOuterMostWrapper AndDecomposition {} = True
checkOuterMostWrapper _ = False

checkOrDecompositionSubstates :: Wrapper -> Bool
checkOrDecompositionSubstates (AndDecomposition a _ _ _ _ _) = all checkOrDecompositionSubstates a
checkOrDecompositionSubstates (OrDecomposition a _ _ _ _ _ _ _ _) = any checkOrDecompositionList (concat a) &&
  all checkOrDecompositionSubstates (concat a)
checkOrDecompositionSubstates _ = True

checkOrDecompositionList :: Wrapper -> Bool
checkOrDecompositionList AndDecomposition {} = True
checkOrDecompositionList OrDecomposition {} = True
checkOrDecompositionList Leaf {} = True
checkOrDecompositionList EndS {} = True
checkOrDecompositionList _ = False

checkAndDecompositionSubstates :: Wrapper -> Bool
checkAndDecompositionSubstates (AndDecomposition a _ _ _ _ _) = length a > 1 && all checkAndDecompositionList a
checkAndDecompositionSubstates (OrDecomposition a _ _ _ _ _ _ _ _) = all checkAndDecompositionSubstates (concat a)
checkAndDecompositionSubstates _ = True

checkAndDecompositionList :: Wrapper -> Bool
checkAndDecompositionList (OrDecomposition a _ _ _ _ _ _ _ _) = all checkAndDecompositionSubstates (concat a)
checkAndDecompositionList _ = False

checkLayout :: Wrapper -> Bool
checkLayout a@(OrDecomposition [[b@AndDecomposition {}]] _ _ _ _ _ _ _ _) = layout a == layout b && checkLayout b
checkLayout (OrDecomposition a _ _ _ _ _ _ _ _) = all checkLayout (concat a)
checkLayout a@(AndDecomposition b _ _ _ _ _) = all (== layout a) (fmap layout b) && all checkLayout b
checkLayout _ = True
