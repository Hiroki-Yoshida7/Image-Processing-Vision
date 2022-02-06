{-# LANGUAGE TemplateHaskell, RecordWildCards #-}

import Vision.GUI
import Image.Processing

autoParam "SParam" "g-"  [  ("sigma","Float",realParam 3 0 20)
                         ,  ("scale","Float",realParam 1 0 5) ]

main = run  $    arr grayscale
            >>>  withParam g
            >>>  observe "gauss" id

g SParam{..} = (scale .*) . gaussS sigma . toFloat

