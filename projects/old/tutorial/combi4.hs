import EasyVision hiding (observe)
import Util.Options

observe winname = monitor' winname (mpSize 20) drawImage

drift r a b = r .* a |+| (1-r) .* b
interpolate (a:b:xs) = a: (0.5.*a |+| 0.5.*b) :interpolate (b:xs)

main = do
    alpha <- getOption "--alpha" 0.9
    run $ camera ~> float . grayscale
      ~~> scanl1 (drift alpha)
      >>= observe "drift"
      ~~> interpolate
      >>= observe "interpolate"

monitor' name sz fun cam = do
    w <- evWindow 0 name sz Nothing (const kbdQuit)
    return $ do
        thing <- cam
        n <- getW w
        inWin w $ do
            fun thing
            text2D 20 20 (show n)
        putW w (n+1)
        return thing
