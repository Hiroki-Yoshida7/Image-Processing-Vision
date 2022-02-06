-- Naive Bayes and "ferns"

import Numeric.LinearAlgebra
import Classifier as C
import System.Random
import Debug.Trace
import Data.List as L
import qualified Data.Map as M
import Data.Maybe(fromMaybe)
import Control.Arrow((&&&))
import Text.Printf(printf)
import Util.Misc(splitEvery,Vec)
import Util.Statistics(randomPermutation)
import Numeric.LinearAlgebra.HMatrix(Seed)
import Util.Options


study prob meth = do
    let (train,test) = prob
    let c = Just . mode . meth train
    putStr "Training error: "
    print $ errorRate $ quality train c
    putStr "Test error: "
    shQuality $ quality test c


main = do
    m <- loadMatrix "../../data/ml/mnist.txt"
    n <- getOption "--n" 100 -- number of ferns
    s <- getOption "--s" 10 -- size of each fern
    let vs = toRows (takeColumns 784 m)
    let ls = map (show.round) $ toList $ flatten $ dropColumns 784 m
    seed <- randomIO
    let mnist = randomPermutation seed $ zip vs ls
    let (train,test) = splitAt 4000 mnist

    randfeats <- (take (n*s) . randomPairs (0,783::Int)) `fmap` randomIO
    let train' = preprocess (randBinFeat randfeats) train
        test'  = preprocess (randBinFeat randfeats) test

    let rawproblem = (train,test)
    putStr "distmed "
    study rawproblem (minDistance euclidean)
--    putStr "mselin "
--    study' rawproblem (multiclass mse)
    putStr "naive bayes 0/1 "
    study (train',test') (bayes naive01)

    let train'' = preprocess (binbool s randfeats) train
        test''  = preprocess (binbool s randfeats) test

    putStr "ferns "
    study (train'',test'') (bayes ferns)

---------------------------------------------------------

-- | generate random pairs of objects in a given range
randomPairs :: (Random t) => (t, t) -> Seed -> [(t, t)]
randomPairs ran seed = partit $ randomRs ran (mkStdGen seed)
    where partit (a:b:rest) = (a,b):partit rest

-- | extract 0-1 properties from a list of pairs of indexes
-- by simple comparison of values
randBinFeat :: [(Int, Int)] -> Vec -> Vec
randBinFeat coordPairs v = fromList $ map g coordPairs
    where g (a,b) = if v@>a > v@>b then 1.0 else 0.0 :: Double

-- | extract boolean features from simple comparison of values
-- from a list of pairs on indexes, grouping them into \"ferns\" of given size.
binbool :: Int -> [(Int, Int)] -> Vec -> [[Bool]]
binbool k coordPairs v = splitEvery k $ map g coordPairs
    where g (a,b) = v@>a > v@>b

