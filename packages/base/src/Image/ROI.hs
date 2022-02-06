-----------------------------------------------------------------------------
{- |
Module      :  Image.ROI
Copyright   :  (c) Alberto Ruiz 2006-8
License     :  GPL-style

Maintainer  :  Alberto Ruiz (aruiz at um dot es)
Stability   :  provisional

Manipulation of regions of interest.

-}
-----------------------------------------------------------------------------

module Image.ROI
( mkROI,
  roiSize,
  fullROI,
  shrink,
  shift,
  getShift,
  intersection,
  union,
  roiArea,
  inROI, inROI',
  roiGrid, roiGridStep,
  roiArray,
  overlap,
  roiFromPixel,
  roiFrom2Pixels,
  roiCenter,
  roiRadius,
  roiDiv,
  roi2poly,
  poly2roi,
  roiAt,
  topLeft,
  bottomRight
) where

import Image.Types
import Util.Geometry

mkROI :: Pixel -> Size -> ROI
mkROI (Pixel r c) (Size h w) = ROI r (r+h-1) c (c+w-1)

roiSize :: ROI -> Size
roiSize (ROI a b x y) = Size { height = b-a+1, width = y-x+1 }


fullROI :: Size -> ROI
fullROI (Size h w) = ROI 0 (h-1) 0 (w-1)


-- | Creates a new roi by reducing in (r,c) units the rows and columns or a given roi. If r or c are negative the roi expands.
shrink :: (Int,Int) -> ROI -> ROI
shrink (r,c) (ROI r1 r2 c1 c2) = ROI (r1+r) (r2-r) (c1+c) (c2-c)

-- | Creates a new roi by moving (r,c) units the position of a given roi.
shift :: (Int,Int) -> ROI -> ROI
shift (r,c) (ROI r1 r2 c1 c2) = ROI (r1+r) (r2+r) (c1+c) (c2+c)

-- | Computes the displacement between the top left corners of two rois 
getShift :: ROI -> ROI -> (Int,Int)
getShift (ROI r11 _ c11 _) (ROI r12 _ c12 _) = (r12 - r11, c12 - c11)

-- | Creates a new roi as the intersection of two given roi's.
intersection :: ROI -> ROI -> ROI
intersection (ROI r1a r2a c1a c2a) (ROI r1b r2b c1b c2b)
    = ROI (max r1a r1b) (min r2a r2b) (max c1a c1b) (min c2a c2b)

-- | obtains the minimum ROI which contains the arguments
union :: ROI -> ROI -> ROI
union (ROI r1a r2a c1a c2a) (ROI r1b r2b c1b c2b)
    = ROI (min r1a r1b) (max r2a r2b) (min c1a c1b) (max c2a c2b)

-- | 'ROI'\'s area in pixels
roiArea :: ROI -> Int
roiArea (ROI r1 r2 c1 c2) = w*h where
    w = max 0 $ c2-c1+1
    h = max 0 $ r2-r1+1

-- | checks that a pixel is in a ROI
inROI :: ROI -> Pixel -> Bool
inROI (ROI r1 r2 c1 c2) (Pixel r c) = r1 <= r && r <= r2 && c1 <= c && c <= c2

-- | checks that a point is in a ROI
inROI' :: Size -> ROI -> Point -> Bool
inROI' sz (ROI r1 r2 c1 c2) = g where
    g (Point x y) = x1 <= x && x <= x2 && y1 <= y && y <= y2
    [Point x1 y1, Point x2 y2] = pixelsToPoints sz [Pixel r2 c2, Pixel r1 c1]


-- TO DO: fix roiGrid

-- | divides a ROI into n x m subregions
roiGrid :: Int -- ^ rows of rois
        -> Int -- ^ columns of rois
        -> ROI -- ^ input ROI
        -> [ROI]
roiGrid kr kc (ROI r1 r2 c1 c2) = take (kr*kc) $ [ROI a (a+dr-1) b (b+dc-1) | a <- [r1,r1+dr .. r2-dr+1]
                                                             , b <- [c1,c1+dc .. c2-dc+1]]
    where dr = (r2-r1+1) `div` kr
          dc = (c2-c1+1) `div` kc

-- | creates a grid of rois of given size and overlap inside a given roi
roiGridStep :: Int -- ^ heigh of rois
            -> Int -- ^ width of rois
            -> Int -- ^ step in rows
            -> Int -- ^ step in columns
            -> ROI -> [ROI]
roiGridStep wr wc sr sc (ROI r1 r2 c1 c2) = [ROI r (r+wr-1) c (c+wc-1) | r<-rs, c<-cs]
    where rs = [r1,r1+sr .. r2-wr+1]
          cs = [c1,c1+sc .. c2-wc+1]

-- | the ratio of common area
overlap :: ROI -> ROI -> Double
overlap roi1 roi2 = fromIntegral ai / fromIntegral (min a1 a2)
    where ai = roiArea (intersection roi1 roi2)
          a1 = roiArea roi1
          a2 = roiArea roi2

-- | creates a square ROI around a pixel (the size of the ROI is (2*radius+1)^2).
roiFromPixel :: Int -- ^ radius
             -> Pixel -> ROI
roiFromPixel rad (Pixel r c) = ROI (r-rad) (r+rad) (c-rad)  (c+rad)

-- | creates a ROI from opposite vertices
roiFrom2Pixels :: Pixel -> Pixel -> ROI
roiFrom2Pixels (Pixel r1 c1) (Pixel r2 c2) = ROI (min r1 r2) (max r1 r2) (min c1 c2) (max c1 c2)

-- | the central pixel of a ROI
roiCenter :: ROI -> Pixel
roiCenter (ROI r1 r2 c1 c2) = Pixel (r1 + (r2-r1+1)`div`2) (c1 + (c2-c1+1)`div`2)

-- | the inverse of roiFromPixel
roiRadius :: ROI -> Int
roiRadius (ROI r1 r2 c1 c2) = min ((r2-r1+1)`div`2) ((c2-c1+1)`div`2)

-- | scale down a ROI (useful for U and V in YUV images)
roiDiv :: Int -> ROI -> ROI
roiDiv k (ROI r1 r2 c1 c2) = ROI (d r1) (d r2) (d c1) (d c2)
  where d = (`div` k)

roi2poly :: Size -> ROI -> Polyline
roi2poly sz (ROI r1 r2 c1 c2) = Closed $ pixelsToPoints sz p
  where
    p = [Pixel r1 c1, Pixel r1 c2, Pixel r2 c2, Pixel r2 c1]

poly2roi :: Size -> Polyline -> ROI
poly2roi sz p = ROI r1 (max (r1+d) r2) c1 (max (c1+d) c2)
  where
    (Closed [p1,_,p3,_]) = bounding p
    [Pixel r1 c1, Pixel r2 c2] = pointsToPixels sz [p1,p3]
    d = 32

roiAt :: ROI -> Pixel -> ROI
roiAt r@(ROI r1 _ c1 _) (Pixel r0 c0) = shift (r0-r1,c0-c1) r

roiArray :: Int -> Int -> Int -> Int -> ROI -> ROI
roiArray h w i j r | ok = roiGrid h w r !! ((i-1)*w+j-1)
                   | otherwise = error "roiArray"
  where
    ok = i >= 1 && i <= h && j >= 1 && j <= w && h > 0 && w > 0


topLeft :: ROI -> Pixel
topLeft (ROI r _ c _) = Pixel r c

bottomRight :: ROI -> Pixel
bottomRight (ROI _ r _ c) = Pixel r c

