import Vision.GUI.Simple
import Image
import Util.Geometry
import Util.Polygon
import Data.Traversable(traverse)
import Util.Options(getRawOption)

main = do
    mbimg <- getRawOption "--image" >>= traverse loadRGB
    
    runIt $ do
        p <- clickPoints "click points" "--points" () (sh mbimg.fst)
        w <- browser "work with them" [] (const id)
        connectWith g p w

sh mbimg pts = Draw [ Draw mbimg
                    , color yellow . drawPointsLabeled $ pts]

g (k,_) (ps,_) = (k, [ pointSz 5 ps
                     , Draw (Closed ps)
                     , color green $ fillPolygon (Polygon ps)
                     , Draw (convexComponents (Polygon ps))
                     ])

