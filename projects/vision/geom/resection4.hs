import Vision.GUI
import Image.Processing
import Vision.Camera
import Util.Options(getRawOption)
import Data.Traversable(traverse)
import Numeric.LinearAlgebra
import Numeric.LinearAlgebra.Util((¦),(#),row, col, diagl)
import Util.Geometry
import Util.Camera
import Util.Options
import Util.Misc(posMin, replaceAt)
import Vision.Camera(refineNewton)

main = do
    mbimg <- getRawOption "--image" >>= traverse loadRGB
    mbref <- getRawOption "--reference" >>= traverse loadMatrix
    let ref = maybe err unsafeMatDat mbref
           where err = error "I need --reference=< text filename with world points in nx3 matrix >"
    runIt $ do
        p <- clickPoints' "click points" "--points" () (sh ref mbimg . fst)
        w <- browser3D "camera resection" [] (const id)
        connectWith (g ref mbimg) p w

sh ref mbimg pts = Draw [ Draw $ fmap (rgb.channelsFromRGB) mbimg
                    , color lightgreen . drawPointsLabeled $ pts ]
  where
    cam = computeCamera pts ref

g ref mbimg (n,_) (ps,_) = (n, [ Draw $ thing computeCamera
                               , Draw $ thing (computeLinearPose 1.7)
                               , Draw $ thing (optimal 1.7)
                               , Draw $ thing (computeLinearPose 2.5)
                               ])
  where
    thing method = [ clearColor white
                        [ color gray $ axes3D 4
                        , color red . pointSz 3 $ drawPoints3DLabeled ref
                        , drcam
                        , pointSz 5 . color orange $ ipts
                        , color lightgray rays
                        ]
            ]
      where
        drcam | length ps < length ref = Draw ()
              | otherwise = color green $ showCamera 2 ic (fmap (toFloat.grayscale.channelsFromRGB) mbimg)

        cam = method ps ref
        ic = infoCam cam
        ipts = toImagePlane ic 2 ps
        invc = invTrans cam
        rays = invc <| map homog ps

withRawMat m ps ref = unsafeFromMatrix $ m (homog $ datMat ps) (homog $ datMat ref)

optimal f ps ref = unsafeFromMatrix $ refineNewton 5 (toMatrix $ computeLinearPose f ps ref) (homog $ datMat ps) (homog $ datMat ref)

--------------------------------------------------------------------------------

clickPoints' :: String -- ^ window name
             -> String -- ^ command line option name for loading points
             -> a      -- ^ additional state
             -> (([Point],a) -> Drawing) -- ^ display function
             -> IO (EVWindow ([Point],a))
clickPoints' name ldopt st sh = do
--    pts <- optionFromFile ldopt []
    mbpts <- getRawOption ldopt >>= traverse loadMatrix
    let pts = maybe [] unsafeMatDat mbpts
    standalone (Size 400 400) name (pts,st) updts acts sh
  where

    updts = [ (key (MouseButton LeftButton), const new)
            , (key (MouseButton RightButton), const move)
            , (key (Char '\DEL'), \_ _ (ps,st) -> if null ps then (ps,st) else (init ps,st))
            ]

    acts = [(ctrlS, \_ _ (ps,_) -> putStrLn . dispf 5 $ datMat ps)]
    ctrlS = kCtrl (key (Char '\DC3'))

    new p (ps,st) = (ps++[p],st)

    move p (ps,st) = (replaceAt [j] [p] ps, st)
      where
        j = posMin (map (distPoints p) ps)

