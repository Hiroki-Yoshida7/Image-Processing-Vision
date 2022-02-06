{- detection of rois based on examples labeled by roisel

$ ./roiclass 'newvideo -benchmark' selectedtest selected1 selected2 etc.

  try to detect similar rois in a new video
  selectedtest is used for error estimation

-}

import EasyVision
import Graphics.UI.GLUT hiding (histogram)
import Control.Monad(when)
import System.Environment(getArgs)
import Numeric.LinearAlgebra
import Classifier
import Data.List(maximumBy,isPrefixOf)
import Text.Printf
import Util.Misc(vec)
import Util.Probability(evidence)

genrois = roiGridStep 50 200 25 25
-- genrois = roiGridStep 100 100 25 25

commonproc im = (chan, highPass8u  Mask5x5 . median Mask5x5 .  grayscale $ chan)
    where chan = channels im

feat = [ (vec. map fromIntegral . lbp 4, grayscale.fst)
       , (histov [0,8 .. 256], snd)
       ]
-- machine =  distance gaussian `onP` mef (NewDimension 15)
-- machine = multiclass mse `onP` mef (ReconstructionQuality 0.95)
-- machine = multiclass mse `onP` mef (NewDimension 10)
-- machine = distance ordinary
machine = multiclass mse

------------------------------------------------------------------------------

main = do
    sz <- findSize
    video:test:files <- fmap (filter (not . isPrefixOf "--")) getArgs
    prepare

    rawexamples <- mapM (readSelectedRois sz) files
    let examples = concatMap (createExamples commonproc genrois feat) (concat rawexamples)
        classifier = machine examples

    putStrLn $ show (length examples) ++ " total examples"

    rawtest <- readSelectedRois sz test
    let test = concatMap (createExamples commonproc genrois feat) rawtest

    putStrLn $ show (length test) ++ " total test examples"


    shConf test (Just . mode . classifier)
    shErr  test (Just . mode . classifier)
    -- evaluation required in "two places" to avoid
    -- relearning the classifier in each frame (!!??)

    (camtest,ctrl) <- mplayer video sz >>= detectStatic 0.01 5 5 (grayscale.channels) id >>= withPause
    w <- evWindow () "Plates detection" sz Nothing  (const (kbdcam ctrl))
    t <- evWindow () "threshold" sz Nothing  (const (kbdcam ctrl))
    launch $ do
        img <- camtest
        let imgproc = commonproc img
            candis = map (\r -> (r,imgproc)) (genrois (theROI img))
        lineWidth $= 1
        setColor' gray
        let pos = filter ((=="+"). mode . classifier. features feat) candis
            best = maximumBy (compare `on` (evidence "+" . classifier) . features feat) pos
        mapM_ (drawROI.fst) pos

        inWin w $ do
            drawImage img
            when (not.null $ pos) $ do
                lineWidth $= 3
                setColor' red
                drawROI (fst best)
--             lineWidth $= 1
--             setColor' white
--             drawVector 100 400 $ features feat best

        inWin t $ when (not.null $ pos) $ do
            drawImage (binarize (grayscale $ channels img) (fst best))

binarize img roi = binarize8u t img where
    t = otsuThreshold (modifyROI (const roi) img)

readSelectedRois sz file = do
    roisraw <- readFile (file++".roi")
    let rois = map read (lines roisraw) :: [ROI]
        nframes = length rois
    cam <- mplayer (file++" -benchmark") sz
    imgs <- sequence (replicate nframes cam)
    putStrLn $ show nframes ++ " cases in " ++ file
    return (zip imgs rois)

createExamples commonproc candirois feat (img,roi) = ps ++ ns
    where candis = candirois (theROI img)
          imgproc = commonproc img
          ps = ejs "+" . sel (>0.5) $ candis
          ns = ejs "-" . sel (<0.2) $ candis
          ejs t = map (\r -> (features feat (r, imgproc), t))
          sel c = filter (c.overlap roi)

shErr d c = putStrLn $ (printf "error %.3f" $ 100 * errorRate (quality d c)) ++ " %"
shConf d c = putStrLn $ format " " (show.round) (confusion $ quality d c)

unitary v = v / scalar (pnorm PNorm2 v)

overROI (feat, sel) (r, obj) = feat (modifyROI (const r) (sel obj))

features fs x = join $ map (flip overROI x) fs

histov l = vec . map fromIntegral . histogram l
