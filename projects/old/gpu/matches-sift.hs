{-# LANGUAGE CPP, RecordWildCards #-}

-- ./matches2 [--size=15] [url1] [url2]

import EasyVision
import Numeric.LinearAlgebra
import Graphics.UI.GLUT hiding (Size, Point)
import Control.Monad(when)
import Data.List(minimumBy)
import Text.Printf(printf)
import Control.Parallel.Strategies
import Vision
import ImagProc.GPU.SIFT
import Util.Options

-----------------------------------------------------------

interestPoints n h orig = feats where
    sigmas = take (n+2) $ getSigmas 1 3
    imr = float $ grayscale $ orig
    feats = take 200 $ fullHessian (usurf 2 4) sigmas 100 h imr

-----------------------------------------------------------
---- two cameras

#define PAR(S) S <- getParam o "S"

main2 = do
    sz@(Size r c) <- findSize

    cam0 <- getCam 0 sz ~> channels
    cam1 <- getCam 1 sz ~> channels

    prepare

    o <- createParameters [("sigma",realParam 1.0 0 3)
                          ,("steps",intParam 3 1 10)
                          ,("n",intParam 13  0 20)
                          ,("tot",intParam 200 1 500)
                          ,("h",realParam 0.2 0 2)
                          ,("mode",intParam 0 0 1)
                          ,("err",realParam 0.3 0 1)
                          ,("ranThres", realParam 0.003 0 0.01)
                          ,("ranProb", realParam 0.9 0.5 1)
                          ]

    wm <- evWindow () "Matches" (Size r (2*c)) Nothing  (const (kbdQuit))

    launchFreq 15 $ do

        PAR(err) :: IO Double
        PAR(n)
--        PAR(ranProb)
--        PAR(ranThres)
        PAR(h)

        orig0 <- cam0
        orig1 <- cam1

        let [feats0,feats1] = parMap rdeepseq (map ip . interestPoints n h) [orig0,orig1]

        let matches = basicMatches (feats0, feats1) distFeat err

        inWin wm $  do
            let pair = blockImage [[grayscale orig0, grayscale orig1]]
            drawImage pair
            pointCoordinates (size pair)
            when (length matches > 0) $ do
                let Size h w = sz
                --setColor 0.5 0.5 0.5
                renderPrimitive Lines $ mapM_ drawPair' matches
                --setColor 1 1 1
                --renderPrimitive Lines $ mapM_ drawPair goodmatches
                --pixelCoordinates sz
                --when (err < 1E-2) $ text2D 20 20 (show (foc,err))

-----------------------------------------------------------------------
-- one camera and click

main1 = do
    sz@(Size r c) <- findSize

    (cam,ctrl) <- getCam 0 sz ~> channels >>= withPause

    prepare

    sift <- getSift
    os <- winSIFTParams
    matchGPU <- getMatchGPU

    o <- createParameters [ ("err", realParam 0.7 0 1)
                          , ("rat", realParam 0.8 0 1) ]





    w <- evWindow ([],undefined) "Interest Points" sz Nothing  (mouse (kbdcam ctrl))
    wm <- evWindow () "Matches" (Size r (2*c)) Nothing  (const (kbdcam ctrl))

    --roi <- getROI w
    --setEVROI w $ roiFromPixel (roiRadius roi `div`2) (roiCenter roi)

    launch $ do

        PAR(err)
        PAR(rat)

        roi <- getROI w

        orig <- cam
        sp <- os
        let feats = sift sp (grayscale orig)
            sel = filter (inROI' sz roi . ipPosition) feats

        --putStrLn ("detected: " ++ show (length feats))

        (vs, prev) <- getW w
        when (null vs && not (null sel)) $ do
            putW w (sel,grayscale orig)

        let matches' = matchGPU err rat vs feats
            matches = map (\[a,b]->(vs!! a, feats!! b)) matches'

            ok = not (null vs) && not (null feats)

        inWin w $ do
            drawImage (rgb orig)
            lineWidth $= 1
            setColor 0 0 0
            drawROI roi
            setColor 0.5 0.5 0.5
            pointCoordinates sz
            drawInterestPoints feats

            when ok $ do
                setColor 1 1 1
                text2D 0.9 0.7 $ printf "%d/%d matches / points" (length matches) (length feats)
                pointCoordinates sz
                drawInterestPoints (map snd matches)

        when ok $ inWin wm $ do
            let pair = blockImage [[prev,grayscale orig]]
            drawImage pair
            pointCoordinates (size pair)
            when (length matches > 0) $ do
                let Size h w = sz
                renderPrimitive Lines $ mapM_ drawPair' matches

--------------------------------------------------------

main = do
    with2 <- getFlag "--2"
    if with2
        then main2
        else main1

-----------------------------------------------------

distFeat = (distv `on` ipDescriptor)

prep = map (g.ipPosition) where g (Point x y) = [x,y]

drawPair (a,b) = vertex (f1 a) >> vertex (f2 b) where
    f1 [x,y] = Point (x/2+0.5) (y/2)
    f2 [x,y] = Point (x/2-0.5) (y/2)


drawPair' (a,b) = vertex (ipPosition $ desp1 a) >> vertex (ipPosition $ desp2 b)
    where
        f1 (Point x y) = Point (x/2+0.5) (y/2)
        f2 (Point x y) = Point (x/2-0.5) (y/2)
        desp1 x = x {ipPosition = f1 (ipPosition x)}
        desp2 x = x {ipPosition = f2 (ipPosition x)}

boxFeat p = do
    drawROI $ roiFromPixel (ipRawScale p) (ipRawPosition p)


mouse _ st (MouseButton LeftButton) Down _ _ = do
    (_,_) <- getW st
    putW st ([],undefined)
mouse def _ a b c d = def a b c d

distv a b = pnorm PNorm2 (a-b)
