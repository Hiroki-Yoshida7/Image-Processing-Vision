-- demo of some functions
-- left click for a menu, right click and drag to select the region of interest
-- examples:
-- ./demo penguin.dv
-- ./demo webcam0

import EasyVision as EV
import Graphics.UI.GLUT hiding (RGB,Size,minmax,histogram,Point)
import GHC.Float(float2Double)
import qualified Data.Colour.Names as Col
import ImagProc.C.Segments

------------------------------------------------------------

main = do

    sz <- findSize

    prepare

    (cam, ctrl)  <- camera >>= withPause


    o <- createParameters [("threshold",realParam 0.5 0 1),
                           ("sigma",realParam 3 0 20),
                           ("threshold2",intParam 128 1 255),
                           ("area",percent 5),
                           ("h",percent 20),
                           ("fracpix",realParam (1.5) 0 10),
                           ("smooth",intParam 3 0 20),
                           ("smooth2",intParam 1 0 10),
                           ("lbpThres",intParam 0 0 100),
                           ("difpix",intParam 5 0 30),
                           ("radius",intParam 5 0 100)]

    w <- evWindow "Gray" "Demo: Gray" sz Nothing (const (kbdcam ctrl))


    let d = height sz `div` 10
    
    let mode m = MenuEntry m $ do { putW w m; windowTitle $= "Demo: "++m }

    attachMenu LeftButton $ Menu $ map mode
        ["RGB","Gray","Red","Green","Blue","H","S"
        , "Median","Gaussian","NGaussian1","FilterBox","FilterMax","Box vs Gauss","Laplacian","HighPass","Histogram"
        ,"Integral","RecStdDev","Threshold","OtsuThres","FloodFill","Contours","ContourD","Distance", "Distance2", "Hessian"
        ,"Corners", "InterestPts", "Segments", "Canny", "DCT", "FFT", "LBP"]

    fft <- genFFT 8 8 DivFwdByN AlgHintFast

    launch (worker w cam o fft)

-----------------------------------------------------------------

worker wDemo cam param fft = do

    th <- getParam param "threshold"
    th2' <- getParam param "threshold2" ::IO Int
    let th2 = fromIntegral th2'
    ph <- getParam param "h" :: IO Int
    let h1 = fromIntegral ph / 100
    smooth <- getParam param "smooth" :: IO Int
    smooth2 <- getParam param "smooth2" :: IO Int
    area <- getParam param "area" :: IO Int
    fracpix <- getParam param "fracpix" :: IO Double
    lbpThres <- getParam param "lbpThres" :: IO Int
    difpix <- getParam param "difpix" :: IO Int
    radius <- getParam param "radius" :: IO Int
    sigma <- getParam param "sigma"

    op <- getW wDemo
    roi <- getROI wDemo
    orig <- cam


    let chan ch = modifyROI (const roi) (ch orig)

        gsmooth = smooth `times` gauss Mask5x5 $ float $ chan grayscale

        edges = canny (th/3,th) . gradients $ gsmooth

    inWin wDemo $ do
        drawImage (rgb orig)
        case op of
            "RGB"   -> return () --drawImage $ chan rgb
            "Gray"  -> drawImage $ chan grayscale
            "Red"   -> drawImage $ chan rCh
            "Green" -> drawImage $ chan gCh
            "Blue"  -> drawImage $ chan bCh
            "H"     -> drawImage $ chan hCh
            "S"     -> drawImage $ chan sCh

            "NGaussian1" -> drawImage $ gsmooth
            "Gaussian" -> drawImage $ gaussS sigma (float (chan grayscale))
            "Median"   -> drawImage $ smooth `times` median Mask5x5 $ chan grayscale
            "HighPass" -> drawImage $ highPass8u Mask5x5 $ smooth `times` median Mask5x5 $ chan grayscale

            "Threshold" -> drawImage $ binarize8u th2 $ chan grayscale
            "OtsuThres" -> drawImage $ binarize8u (otsuThreshold $ chan grayscale) $ chan grayscale

            "Laplacian"-> drawImage $ scale32f8u (-1) 1
                                    . laplace Mask5x5
                                    . times smooth (gauss Mask5x5)
                                    . scale8u32f (-1) 1
                                    $ chan grayscale

            "Hessian"  -> drawImage $ autoscale
                                    . sqrt32f
                                    . abs32f
                                    . hessian
                                    . gradients
                                    $ gaussS sigma (float (chan grayscale))

            "Canny"    -> drawImage $ edges

            "Distance" -> drawImage $ (1/60) .* distanceTransform [1,1.4,2.2] (notI $ edges)
            "Distance2"-> drawImage $ ((1/60) .*)
                                    . distanceTransform [1,1.4,2.2]
                                    . toGray
                                    . thresholdVal32f th 1 IppCmpGreater
                                    . thresholdVal32f th 0 IppCmpLess
                                    $ float $ chan grayscale

            "DCT"      -> drawImage $ sqrt32f . abs32f . dct . float $ chan grayscale

            "Segments" -> do let segs = segments 4 1.5 5 40 20 True (chan grayscale)
                             drawROI roi
                             --setColor 1 1 0
                             setColor' Col.yellow
                             lineWidth $= 2
                             pointCoordinates (size (grayscale orig))
                             renderPrimitive Lines $ mapM_ vertex segs

            "Histogram" -> do drawImage $ chan grayscale
                              pointCoordinates (size (grayscale orig))
                              setColor 1 1 0
                              lineWidth $= 2
                              renderSignal $ map (*5) $ histogramN [0..256] $ chan grayscale

            "LBP"       -> do let h = lbpN lbpThres (chan grayscale)
                              drawROI roi
                              pointCoordinates (size (grayscale orig))
                              setColor 0 0 0
                              renderAxes
                              setColor 1 0 0
                              renderSignal $ map (*0.2) (tail h)

            "Corners"   -> do let ips = getCorners smooth 7 h1 500 $ float (chan grayscale)
                              drawROI roi
                              setColor 1 0 0
                              pointSize $= 3
                              renderPrimitive Points (mapM_ vertex ips)
                              text2D 10 20 (show $ length ips)

            "Features" -> do let ips = getSaddlePoints smooth 7 h1 500 20 10 $ float (chan grayscale)
                             drawROI roi
                             pointCoordinates (size $ chan grayscale)
                             setColor 1 0 0
                             pointSize $= 3
                             text2D 0.9 0 (show $ length ips)
                             drawInterestPoints ips

            "InterestPts" -> do let imr = float (chan grayscale)
                                    feats = fullHessian (usurf 2 4) (take (13+2) $ getSigmas 1.0 3) 100 0.3 imr
                                drawImage (chan rgb)
                                let boxfeat p = drawROI $ roiFromPixel (ipRawScale p) (ipRawPosition p)
                                setColor' Col.red
                                mapM_ boxfeat feats


            "Contours" -> do let (Size h w) = size (chan grayscale)
                                 pixarea = h*w*area`div`1000
                                 redu = douglasPeuckerClosed fracpix
                                 cs1 = map (redu.fst3) $ contours 100 pixarea th2 True (chan grayscale)
                                 cs2 = map (redu.fst3) $ contours 100 pixarea th2 False (chan grayscale)
                             drawROI roi
                             pixelCoordinates (size $ chan grayscale)
                             setColor 1 0 0
                             lineWidth $= 2
                             mapM_ shcont (cs1++cs2)

            "ContourD" -> do let (Size h w) = size (chan grayscale)
                             setColor 1 0 0
                             pointSize $= 5
                             let f = douglasPeucker fracpix . rot . rot . douglasPeucker fracpix
                                 --tc (Closed l) = l
                                 --f = map tc . selectPolygons 0.1 8 . return
                             --pointCoordinates (size $ chan grayscale)
                             case contourAt difpix (chan grayscale) (Pixel (h`div`2) (w`div`2)) of
                                Nothing -> return ()
                                Just l  -> shcontP $ f l
                             pointCoordinates (size $ chan grayscale)
                             setColor 1 1 1
                             renderAxes

            "FloodFill" -> do im <- cloneClear
                                 $ modifyROI (shrink (1,1))
                                 $ binarize8u th2
                                 $ smooth `times` median Mask5x5 
                                 $ chan grayscale
                              let (Size h w) = size im
                                  start = (Pixel (h `div`2 ) (w `div`2))
                              --(r,a,v) <- floodFill8uGrad im start 5 5 128
                              (r,a,v) <- floodFill8u im start 128
                              --(r,a) <- floodFill8uGrad im (snd $ maxIndx8u im) th2 th2 128
                              drawImage (modifyROI (const r) im)
                              pointCoordinates (size $ chan grayscale)
                              setColor 1 1 0
                              text2D 0.9 0.6 (show (a,v))
                              renderAxes

            "FFT" ->       do let p2roi = ROI (r1 roi) (r1 roi + 2^8-1) (c1 roi) (c1 roi + 2^8-1)
                                  d = sqrt32f . powerSpectrum . magnitudePack . fft
                                    $ modifyROI (const p2roi) gsmooth
                                  c@(Pixel r0 c0) = roiCenter (theROI d)
                              EV.set 0 (roiFrom2Pixels c c) d
                              let (m,_) = maxIndx d
                              drawImage $ (1/m) .* d

            "Integral"  -> do let i = integral edges
                                  ROI r1 r2 c1 c2 = theROI i
                                  vert = sampleLine32f i (Pixel r1 c2) (Pixel r2 c2)
                              drawImage . autoscale $ i
                              pointCoordinates (size i)
                              renderSignal (map (float2Double.(/(2*last vert))) vert)

            "RecStdDev" -> do let i = rectStdDev radius radius .  sqrIntegral $ chan grayscale
                              drawImage . autoscale $ i

            "FilterBox" -> do let i = filterBox radius radius . float $ chan grayscale
                              drawImage i

            "FilterMax" -> do let i = filterMax radius . float $ chan grayscale
                              drawImage i

            "Box vs Gauss"-> do let s = float (chan grayscale)
                                    g = gaussS sigma s
                                    b = filterBox radius radius s
                                    ROI r1 r2 c1 c2 = theROI s
                                    cm = (c1 + c2) `div` 2
                                    roi1 = ROI r1 r2 c1 cm
                                    roi2 = ROI r1 r2 cm c2
                                drawImage (modifyROI (const roi1) g)
                                drawImage (modifyROI (const roi2) b)

-----------------------------------



autoscale im = f im
    where (mn,mx) = minmax im
          f = if mn == mx then scale32f8u 0 1 else scale32f8u mn mx

fst3 (a,_,_) = a

shcont ( c) = do
    renderPrimitive LineLoop $ mapM_ vertex c

shcontP ( c) = do
    renderPrimitive LineLoop $ mapM_ vertex c
    renderPrimitive Points $ mapM_ vertex c
    pointSize $= 10
    renderPrimitive Points $ vertex (head c)

times n f = (!!n) . iterate f

rot l = tail l ++ [head l]
