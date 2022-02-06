{-# LANGUAGE Arrows #-}

import Vision.GUI
import Image.Processing
import Util.Geometry
import Contours
import Contours.Polygons
import Numeric.LinearAlgebra((<>))
import Vision(cameraFromHomogZ0,estimateHomographyRaw,ht,scaling) 
import Util.Misc(rotateLeft,posMax)

main = run $ proc im -> do 
                let g = grayscale im
                prev <- delay zero -< g
                let cs = map (smoothPolyline 4) . otsuContours $ g
                    ps = take 1 . polygons 10 5 (4, 4) $ cs
                    s = f prev g ps
                (y,_,_) <- sMonitor "recursive" dr -< (s,g,ps)
                returnA -< y

-- dr would not be in scope if defined inside the proc
dr _ (s,g,ps) = [ Draw s
                , Draw [ Draw g, (Draw . map (drawContourLabeled blue red white 2 3)) ps ] ]

otsuContours = contours 1000 100 . notI . otsuBinarize

f a im (c:_) = warpon a [(h,im)]
  where
    h = estimateHomographyRaw (g c) [[1,r],[-1,r],[-1,-r],[1,-r]] <> scaling 0.95
      where
        r = 0.75
        g (Closed ps) = map (\(Point x y) -> [x,y]) (up ps)
        up = rotateLeft (k+2)
        k = posMax $ map segmentLength (asSegments c)
f _ x _ = x

zero = constantImage 0 (Size 100 100)

