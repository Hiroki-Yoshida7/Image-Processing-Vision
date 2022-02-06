-- average of all rectangles found

import EasyVision
import ImagProc.C.Segments
import Text.Printf(printf)
import Util.Options

drift alpha = virtualCamera drifter
    where drifter (a:b:rest) = a : drifter ((alpha .* a |+| (1-alpha).* b):rest)

main = do
    sz <- findSize
    ratio <- getOption "--ratio" (sqrt 2)
    alpha <- getOption "--alpha" 0.9
    let k = height sz `div` 32
    let szR = Size (32*k) (round (32*fromIntegral k*ratio))
        nm = "ratio " ++ printf "%.2f" ratio
    prepare

    cam <- getCam 0 (mpSize 20)
           >>= monitor "video" (mpSize 5) drawImage
           ~>  channels
           >>= onlyRectangles segments szR ratio grayscale
           ~~> map float . concat
           >>= drift alpha

    w <- evWindow () nm sz Nothing (const $ kbdQuit)

    launch $ do
        inWin w $ cam >>= drawImage
