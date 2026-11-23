--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Data.List (sortOn, intersperse, intercalate, isPrefixOf, nub)
import           Hakyll
import           Hakyll.Web.Template.Context (getItemUTC)
import           Control.Applicative
import           Control.Monad (forM_, unless)
import           Data.Time.Format (TimeLocale(..), defaultTimeLocale)
import           Data.Maybe
import           Data.Map (fromListWith, keys)
import           Data.Time.Format (formatTime)
import           Data.Time.Clock (UTCTime)
import           Data.Ord (Down(..))

import           Text.Blaze.Html (toHtml, toValue, (!))
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as A

import           Text.Pandoc.Definition
import           Text.Pandoc.Shared
import           Text.Pandoc.Options
import           Text.Pandoc.Walk (walkM, walk)

import qualified Data.Map as M
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import qualified Data.ByteString.Lazy as LBS
import           Data.Word (Word8)
import           Data.Char (toLower)
import           System.FilePath (dropExtension, takeExtension)
import           System.IO (IOMode(ReadMode), withBinaryFile)
import           Text.HTML.TagSoup (Tag(TagOpen), parseTags)
-- NB: only the *type* `Image` is imported (no data constructor) so it does not
-- clash with Pandoc's `Image` inline constructor used in makeImagesResponsive.
import           Codec.Picture
                   ( Image, DynamicImage(..), PixelRGB8(..), PixelRGBA8(..)
                   , decodeImage, convertRGB8, convertRGBA8
                   , generateImage, pixelAt, imageWidth, imageHeight )
import           Codec.Picture.Types (convertImage, pixelFold, pixelMap)
import           Codec.Picture.Jpg (encodeJpegAtQuality)
import           Codec.Picture.Extra (crop, scaleBilinear)

--------------------------------------------------------------------------------
-- Used to specify whether to take all or some of an item list
data ItemCount = All | Only Int
--------------------------------------------------------------------------------

siteUrl = "https://invariante.co"

maybeTake :: ItemCount -> [a] -> [a]
maybeTake All  = id
maybeTake (Only n) = take n

takeRecentFirst n = fmap (maybeTake n) . recentFirst

sortAndGroup assocs = fromListWith (++) [(k, [v]) | (k, v) <- assocs]

--------------------------------------------------------------------------------

serveFilesAt routePattern =
  match routePattern $ do
  route   idRoute
  compile copyFileCompiler

type Year = String

data DateAndYear =
    DateAndYear { date :: UTCTime
                , year :: Year                  
                }
  
getTimeInfo :: (MonadFail m, MonadMetadata m) => Identifier -> m DateAndYear
getTimeInfo id = do 
    time <- getItemUTC defaultTimeLocale id
    return $ DateAndYear { date =time, year = formatTime defaultTimeLocale "%Y" time }

-- Make images responsive by adding appropriate attributes
makeImagesResponsive :: Pandoc -> Pandoc
makeImagesResponsive = walk processImage
  where
    processImage :: Inline -> Inline
    processImage (Image attr alt (url, title)) = 
      Image ("", ["responsive-image"], []) alt (url, title)
    processImage x = x

-- Custom Pandoc compiler with responsive images
responsiveImagesCompiler :: Compiler (Item String)
responsiveImagesCompiler = do
    pandocCompilerWithTransform
        defaultHakyllReaderOptions
        defaultHakyllWriterOptions
        makeImagesResponsive

homepageTag :: Context a
homepageTag = constField "is_homepage" "true"

--------------------------------------------------------------------------------
-- Open Graph social cards
--
-- Every post/draft that declares an `image:` gets a 1200x630 (1.91:1) card
-- generated at build time from that image, compressed well under 1 MB. The
-- template's og:image points at the generated `<name>-og.jpg`. Authors just set
-- `image:` to the real photo; no manual cropping. Non-raster sources (e.g. SVG)
-- keep their original image as the og:image.

ogWidth, ogHeight :: Int
ogWidth  = 1200
ogHeight = 630

ogQuality :: Word8
ogQuality = 80

-- How a source that isn't already 1.91:1 is fit into the card.
--   Cover   = center-crop to fill (punchy; best for photos)
--   Contain = scale whole image to fit, fill the rest (never crops content)
data OgFit = Cover | Contain

-- Site-wide default. Override per post with front matter `og_fit: cover|contain`.
defaultOgFit :: OgFit
defaultOgFit = Cover

parseOgFit :: String -> OgFit
parseOgFit s = case map toLower s of
    "contain" -> Contain
    _         -> Cover

resolveOgFit :: Metadata -> OgFit
resolveOgFit md = maybe defaultOgFit parseOgFit (lookupString "og_fit" md)

-- Content whose `image:` we turn into cards.
ogSourcePattern :: Pattern
ogSourcePattern = "posts/*" .||. "drafts/*" .||. "shared-drafts/*"

-- Only formats JuicyPixels can decode become cards; others fall back to original.
isRasterImage :: FilePath -> Bool
isRasterImage p =
    map toLower (takeExtension p) `elem`
        [".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff", ".gif"]

-- "images/foo.jpeg" -> "images/foo-og.jpg" (works with or without leading slash)
toOgPath :: FilePath -> FilePath
toOgPath p = dropExtension p ++ "-og.jpg"

dropLeadingSlash :: FilePath -> FilePath
dropLeadingSlash ('/':rest) = rest
dropLeadingSlash p          = p

-- The og:image URL for the current item (used in templates/default.html).
ogImageField :: Context a
ogImageField = field "ogimage" $ \item -> do
    mbImg <- getMetadataField (itemIdentifier item) "image"
    case mbImg of
        Just img | isRasterImage img -> return (toOgPath img)
                 | otherwise         -> return img   -- SVG etc.: use original
        Nothing                      -> noResult "no image"

-- Present only when a real 1200x630 card exists (gates og:image:width/height).
ogCardField :: Context a
ogCardField = field "ogcard" $ \item -> do
    mbImg <- getMetadataField (itemIdentifier item) "image"
    case mbImg of
        Just img | isRasterImage img -> return "true"
        _                            -> noResult "no card"

ogContext :: Context a
ogContext = ogImageField `mappend` ogCardField

ogRoute :: Routes
ogRoute = customRoute (toOgPath . toFilePath)

ogCardCompiler :: M.Map FilePath OgFit -> Compiler (Item BS.ByteString)
ogCardCompiler fitMap = do
    path <- toFilePath <$> getUnderlying
    let fit = M.findWithDefault defaultOgFit path fitMap
    src <- itemBody <$> getResourceLBS
    case decodeImage (LBS.toStrict src) of
        Right dyn -> makeItem (LBS.toStrict (encodeCard (renderCard fit (convertRGB8 dyn))))
        Left _    -> makeItem (LBS.toStrict src)

encodeCard :: Image PixelRGB8 -> LBS.ByteString
encodeCard = encodeJpegAtQuality ogQuality . convertImage

renderCard :: OgFit -> Image PixelRGB8 -> Image PixelRGB8
renderCard Cover   = coverCard
renderCard Contain = containCard

-- Center-crop to the target ratio, then scale to exactly 1200x630.
coverCard :: Image PixelRGB8 -> Image PixelRGB8
coverCard img =
    let w       = imageWidth img
        h       = imageHeight img
        target  = fromIntegral ogWidth / fromIntegral ogHeight :: Double
        current = fromIntegral w / fromIntegral h
        (cw, ch)
            | current > target = (round (fromIntegral h * target), h)
            | otherwise        = (w, round (fromIntegral w / target))
        x0 = (w - cw) `div` 2
        y0 = (h - ch) `div` 2
    in scaleBilinear ogWidth ogHeight (crop x0 y0 cw ch img)

-- Scale whole image to fit inside 1200x630, centered on a fill of the image's
-- average color (never crops content).
containCard :: Image PixelRGB8 -> Image PixelRGB8
containCard img =
    let w      = imageWidth img
        h      = imageHeight img
        scale  = min (fromIntegral ogWidth  / fromIntegral w)
                     (fromIntegral ogHeight / fromIntegral h) :: Double
        fw     = max 1 (round (fromIntegral w * scale))
        fh     = max 1 (round (fromIntegral h * scale))
        scaled = scaleBilinear fw fh img
        offX   = (ogWidth  - fw) `div` 2
        offY   = (ogHeight - fh) `div` 2
        bg     = averageColor scaled
        pick x y
            | x >= offX && x < offX + fw && y >= offY && y < offY + fh =
                pixelAt scaled (x - offX) (y - offY)
            | otherwise = bg
    in generateImage pick ogWidth ogHeight

averageColor :: Image PixelRGB8 -> PixelRGB8
averageColor im =
    let (rs, gs, bs, n) = pixelFold acc (0, 0, 0, 0 :: Int) im
        acc (r, g, b, c) _ _ (PixelRGB8 pr pg pb) =
            (r + fromIntegral pr, g + fromIntegral pg, b + fromIntegral pb, c + 1)
        d = max 1 n
    in PixelRGB8 (fromIntegral (rs `div` d))
                 (fromIntegral (gs `div` d))
                 (fromIntegral (bs `div` d))

--------------------------------------------------------------------------------
-- Responsive content images
--
-- Posts embed camera originals many times wider than any layout shows them.
-- Every image wide enough to gain from it gets width-capped copies at build
-- time, and each <img> that points at one gets a `srcset`, so a phone downloads
-- a few hundred KB instead of several MB. Like the Open Graph cards, the copies
-- live only in _site/.

-- Steps of the ladder, ascending. The last one covers the full content column
-- on a 2x display; nothing on the site is ever shown larger.
imageWidths :: [Int]
imageWidths = [480, 960, 1440, 1920]

-- markdown.css caps the body at 1000 px and insets the article by 30 px a side.
bodyWidth, contentWidth :: Int
bodyWidth    = 1000
contentWidth = bodyWidth - 60

-- A browser picks from the ladder before it knows the layout, so the slot width
-- is stated here. Narrower slots - floats, galleries - are left to over-state
-- their width: the browser then takes a step larger than it needs, never one
-- too small to stay sharp.
imageSizes :: String
imageSizes =
    "(max-width: " ++ show bodyWidth ++ "px) 100vw, " ++ show contentWidth ++ "px"

copyQuality :: Word8
copyQuality = 82

-- Everything whose body can embed an image.
contentPattern :: Pattern
contentPattern = ogSourcePattern .||. "*.md"

-- The copies built for an image, and the width of the source they came from.
-- The source closes the `srcset`: a display that outruns the last copy then
-- still gets the sharpest file there is, as it did before any of this.
data ImageCopies = ImageCopies
    { sourceWidth :: Int
    , copyWidths  :: [Int]
    }

-- Keyed by repository path. An image with no copy worth building is absent and
-- is served as it is.
type ImageManifest = M.Map FilePath ImageCopies

-- Only the images that content embeds get copies: the site chrome - the feed
-- and theme icons - is shown a few pixels wide, under a `sizes` that describes
-- the article column.
imageManifest :: [FilePath] -> [FilePath] -> IO ImageManifest
imageManifest images content = do
    embedded <- referencedImages content
    M.fromList . catMaybes <$> mapM entry (filter (`elem` embedded) images)
  where
    entry path = fmap (ladderFor path =<<) (readImageSize path)
    ladderFor path (w, _) =
        case takeWhile (worthBuilding w) imageWidths of
            [] -> Nothing
            ws -> Just (path, ImageCopies { sourceWidth = w, copyWidths = ws })
    -- A step that is almost as wide as the source saves nothing and can even
    -- come out larger than the file it replaces.
    worthBuilding source step = step * 5 <= source * 4

-- Post images are written as raw HTML, so the markdown is read with the same
-- parser that rewrites the rendered page.
referencedImages :: [FilePath] -> IO [FilePath]
referencedImages sources = nub . concat <$> mapM imagesIn sources
  where
    imagesIn path = embeddedPaths <$> BS.readFile path
    embeddedPaths markdown =
        [ path
        | TagOpen name attrs <- parseTags markdown
        , name == BSC.pack "img"
        , Just src <- [lookup (BSC.pack "src") attrs]
        , let path = repositoryPath (BSC.unpack src)
        , "images/" `isPrefixOf` path ]

sourcesAtWidth :: ImageManifest -> Int -> [Identifier]
sourcesAtWidth manifest w =
    [ fromFilePath path
    | (path, copies) <- M.toList manifest, w `elem` copyWidths copies ]

-- "images/foo.png" -> "images/foo-960.jpg". Also used on the URLs of the
-- rendered page, so it must work on any spelling of the path.
atWidth :: Int -> FilePath -> FilePath
atWidth w path = dropExtension path ++ '-' : show w ++ ".jpg"

resizedImageCompiler :: Int -> Compiler (Item BS.ByteString)
resizedImageCompiler w = do
    bytes <- LBS.toStrict . itemBody <$> getResourceLBS
    -- An image JuicyPixels cannot read keeps its original bytes, so the page
    -- still shows it.
    makeItem (fromMaybe bytes (resizeToWidth w bytes))

-- Copies are JPEG whatever the source is. The screenshots on the site are PNGs
-- that this PNG encoder writes back twice as large as the camera originals it
-- is meant to replace; JPEG keeps their text readable at a tenth of the bytes.
resizeToWidth :: Int -> BS.ByteString -> Maybe BS.ByteString
resizeToWidth w bytes = do
    dyn <- either (const Nothing) Just (decodeImage bytes)
    return . LBS.toStrict . encodeJpegAtQuality copyQuality
           . convertImage . scaleToWidth w . flattened $ dyn

scaleToWidth :: Int -> Image PixelRGB8 -> Image PixelRGB8
scaleToWidth w img = scaleBilinear w h img
  where
    h = max 1 (round (fromIntegral (imageHeight img) * ratio))
    ratio = fromIntegral w / fromIntegral (imageWidth img) :: Double

-- JPEG has no alpha channel, so transparency is resolved before the scaling
-- that would otherwise bleed the colors hidden under it. White is what both
-- themes show behind an image: the light one directly, the dark one through the
-- invert filter it puts over the whole page.
flattened :: DynamicImage -> Image PixelRGB8
flattened dyn
    | transparent dyn = pixelMap onWhite (convertRGBA8 dyn)
    | otherwise       = convertRGB8 dyn
  where
    onWhite (PixelRGBA8 r g b a) = PixelRGB8 (over r a) (over g a) (over b a)
    over c a = fromIntegral
        ((fromIntegral c * fromIntegral a + 255 * (255 - fromIntegral a)) `div` 255 :: Int)

transparent :: DynamicImage -> Bool
transparent dyn = case dyn of
    ImageYA8 _    -> True
    ImageYA16 _   -> True
    ImageRGBA8 _  -> True
    ImageRGBA16 _ -> True
    _             -> False

-- Point every <img> at the copies built for it. This runs on the rendered page,
-- after relativizeUrls, because post images are written as raw HTML: they reach
-- Pandoc as opaque raw blocks, never as the Image inline that a walk can see.
addImageSrcsets :: ImageManifest -> Item String -> Compiler (Item String)
addImageSrcsets manifest = return . fmap (withTags withSrcset)
  where
    withSrcset (TagOpen "img" attrs)
        | Just src    <- lookup "src" attrs
        , Nothing     <- lookup "srcset" attrs
        , Just copies <- M.lookup (repositoryPath src) manifest =
            TagOpen "img" (attrs ++ [ ("srcset", srcset src copies)
                                    , ("sizes", imageSizes) ])
    withSrcset tag = tag
    srcset src copies = intercalate ", " $
        [ candidate (atWidth w src) w | w <- copyWidths copies ]
        ++ [ candidate src (sourceWidth copies) ]
    candidate url w = url ++ " " ++ show w ++ "w"

-- "/images/foo.jpeg" and "../images/foo.jpeg" both name "images/foo.jpeg".
repositoryPath :: String -> FilePath
repositoryPath url = case url of
    '/'             : rest -> repositoryPath rest
    '.' : '/'       : rest -> repositoryPath rest
    '.' : '.' : '/' : rest -> repositoryPath rest
    _                      -> url

--------------------------------------------------------------------------------
-- Image headers
--
-- JuicyPixels reports the size of an image only by decoding all of it, which is
-- minutes of work across the images directory and would be paid on every build.
-- The JPEG and PNG headers are read directly instead. A header that cannot be
-- read means no copies for that image: it is served as it is, as before.

readImageSize :: FilePath -> IO (Maybe (Int, Int))
readImageSize path =
    withBinaryFile path ReadMode $ \h -> headerSize <$> BS.hGet h headerBytes

-- An embedded EXIF thumbnail can push a JPEG's frame header a long way in.
headerBytes :: Int
headerBytes = 256 * 1024

headerSize :: BS.ByteString -> Maybe (Int, Int)
headerSize bs
    | BS.pack [0x89, 0x50, 0x4E, 0x47] `BS.isPrefixOf` bs = pngSize bs
    | BS.pack [0xFF, 0xD8]             `BS.isPrefixOf` bs = jpegSize bs
    | otherwise                                           = Nothing

-- The IHDR chunk is first and holds the size in its first eight bytes.
pngSize :: BS.ByteString -> Maybe (Int, Int)
pngSize bs
    | BS.take 4 (BS.drop 12 bs) == BSC.pack "IHDR" =
        (,) <$> bigEndian 4 16 bs <*> bigEndian 4 20 bs
    | otherwise = Nothing

-- Walk the marker segments up to the frame header, which carries the size.
jpegSize :: BS.ByteString -> Maybe (Int, Int)
jpegSize bs = segmentAt 2
  where
    segmentAt i = do
        0xFF   <- byteAt i bs
        j      <- markerAt (i + 1)
        marker <- byteAt j bs
        if isFrameHeader marker
            then (,) <$> bigEndian 2 (j + 6) bs <*> bigEndian 2 (j + 4) bs
            else if hasNoPayload marker
                then segmentAt (j + 1)
                else do
                    len <- bigEndian 2 (j + 1) bs
                    if len < 2 then Nothing else segmentAt (j + 1 + len)
    -- Any number of 0xFF fill bytes may precede a marker.
    markerAt j = do
        b <- byteAt j bs
        if b == 0xFF then markerAt (j + 1) else Just j
    isFrameHeader m = m >= 0xC0 && m <= 0xCF && m `notElem` [0xC4, 0xC8, 0xCC]
    hasNoPayload m = m == 0x01 || (m >= 0xD0 && m <= 0xD9)

byteAt :: Int -> BS.ByteString -> Maybe Word8
byteAt i bs
    | i >= 0 && i < BS.length bs = Just (BS.index bs i)
    | otherwise                  = Nothing

bigEndian :: Int -> Int -> BS.ByteString -> Maybe Int
bigEndian n i bs =
    foldl (\acc b -> acc * 256 + fromIntegral b) 0
        <$> mapM (\k -> byteAt k bs) [i .. i + n - 1]

main :: IO ()
main = hakyll $ do
    serveFilesAt "images/*"
    serveFilesAt "images/**/*"
    serveFilesAt "code/*"
    serveFilesAt "scripts/*"
    serveFilesAt "assets/*"
    serveFilesAt "robots.txt"
    serveFilesAt "pgp.txt"
    serveFilesAt "keybase.txt"

    -- Generate 1200x630 Open Graph cards from each post's `image:`
    heroMeta <- getAllMetadata ogSourcePattern
    let ogFitMap = M.fromList
            [ (dropLeadingSlash img, resolveOgFit md)
            | (_, md)   <- heroMeta
            , Just img  <- [lookupString "image" md]
            , isRasterImage img ]
    match (fromList (map fromFilePath (M.keys ogFitMap))) $ version "og" $ do
        route   ogRoute
        compile (ogCardCompiler ogFitMap)

    -- Build the width-capped copies that back the `srcset` of content images
    images   <- map toFilePath <$> getMatches ("images/*" .||. "images/**/*")
    content  <- map toFilePath <$> getMatches contentPattern
    manifest <- preprocess (imageManifest images content)
    forM_ imageWidths $ \width -> do
        let sources = sourcesAtWidth manifest width
        unless (null sources) $
            match (fromList sources) $ version (show width ++ "w") $ do
                route   (customRoute (atWidth width . toFilePath))
                compile (resizedImageCompiler width)

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    -- build up tags 
    tags <- buildTags "posts/*" (fromCapture "tags/*.html")
    tagsRules tags $ \tag pattern -> do 
        let title = "Posts tagged with \"" ++ tag ++ "\"" 
        route idRoute 
        compile $ do 
            posts <- recentFirst =<< loadAll pattern 
            let ctx = constField "title" title
                      `mappend` listField "posts" postCtx (return posts)
                      `mappend` ogContext
                      `mappend` activeClassField
                      `mappend` defaultContext
            makeItem "" 
                >>= loadAndApplyTemplate "templates/tag.html" ctx 
                >>= loadAndApplyTemplate "templates/default.html" ctx 
                >>= relativizeUrls

    let tagsPostCtx = postCtxWithTags tags
    match "drafts/*" $ do
        route $ setExtension "html"
        compile $ responsiveImagesCompiler
            >>= loadAndApplyTemplate "templates/post.html" tagsPostCtx
            >>= loadAndApplyTemplate "templates/default.html" tagsPostCtx
            >>= relativizeUrls
            >>= addImageSrcsets manifest

    create ["drafts.html"] $ do
        route idRoute
        compile $ do
            drafts <- recentFirst =<< loadAll "drafts/*"
            let archiveCtx =
                    listField "posts" postCtx (return drafts) `mappend`
                    constField "title" "Borradores"           `mappend`
                    siteCtx

            makeItem ""
                >>= loadAndApplyTemplate "templates/drafts.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls

    match "shared-drafts/*" $ do
        route $ setExtension "html"
        compile $ responsiveImagesCompiler
            >>= loadAndApplyTemplate "templates/post.html" tagsPostCtx
            >>= loadAndApplyTemplate "templates/default.html" tagsPostCtx
            >>= relativizeUrls
            >>= addImageSrcsets manifest

    create ["shared-drafts.html"] $ do
        route idRoute
        compile $ do
            drafts <- recentFirst =<< loadAll "shared-drafts/*"
            let archiveCtx =
                    listField "posts" postCtx (return drafts) `mappend`
                    constField "title" "Shared drafts"           `mappend`
                    siteCtx

            makeItem ""
                >>= loadAndApplyTemplate "templates/post-list.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls


    match "posts/*" $ do
        route $ setExtension "html"
        compile $ responsiveImagesCompiler
            >>= loadAndApplyTemplate "templates/post.html"    tagsPostCtx
            >>= saveSnapshot "content"
            >>= loadAndApplyTemplate "templates/disqus.html"  tagsPostCtx
            >>= loadAndApplyTemplate "templates/default.html" tagsPostCtx
            >>= relativizeUrls
            >>= addImageSrcsets manifest

    nonPostPage manifest "gifts-guide.md"

    nonPostPage manifest "side-projects.md"

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            postsWithYears <- sortAndGroup <$> mapM (\post -> fmap (\timeInfo -> (year timeInfo, (date timeInfo, post))) (getTimeInfo $ itemIdentifier post)) posts
            let years = reverse $ keys postsWithYears
            let postsSortedRecentFirst = map snd . sortOn (Down . fst)
            let postsItemsWithYears = mapM makeItem $ fmap (\year -> (year, postsSortedRecentFirst (postsWithYears M.! year))) years

            let postWithYearsCtx =
                    listField "postsWithYears"
                              (
                                field "year" (return . fst . itemBody) `mappend`
                                listFieldWith "posts" postCtx (return . snd . itemBody)
                              )
                              postsItemsWithYears

            let archiveCtx =
                    postWithYearsCtx `mappend`
                    constField "title" "Blog" `mappend`
                    siteCtx

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls

    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let indexCtx =
                    listField "posts" postCtx (return $ maybeTake (Only 5) posts) `mappend`
                    homepageTag `mappend`
                    siteCtx

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateCompiler

    create ["feed.xml"] $ do
        route   $ idRoute
        compile $ do
          let feedCtx = postCtx `mappend` bodyField "description"
          posts <- takeRecentFirst (Only 5) =<< loadAllSnapshots "posts/*" "content"
          renderRss feedConfig feedCtx posts

--------------------------------------------------------------------------------

nonPostPage manifest name =
    create [ name ] $ do
        route (setExtension ".html")
        compile $ responsiveImagesCompiler
            >>= loadAndApplyTemplate "templates/default.html" siteCtx
            >>= relativizeUrls
            >>= addImageSrcsets manifest

draftCtx :: Context String
draftCtx = defaultContext `mappend` activeClassField

postCtx :: Context String
postCtx =
    dateField "date" "%b %d %Y" `mappend`
    dateField "simpleDate" "%b %d" `mappend`
    siteCtx

siteCtx :: Context String
siteCtx =
    ogContext `mappend`
    activeClassField `mappend`
    defaultContext

postCtxWithTags :: Tags -> Context String 
postCtxWithTags tags = tagPillsField "tags" tags `mappend` postCtx

-- Each tag as a pill, instead of Hakyll's comma-separated links.
tagPillsField :: String -> Tags -> Context a
tagPillsField =
    tagsFieldWith getTags renderPill (mconcat . intersperse " ")
  where
    renderPill _   Nothing         = Nothing
    renderPill tag (Just filePath) = Just $
        H.a ! A.class_ "tag__pill" ! A.href (toValue (toUrl filePath)) $ toHtml tag

feedConfig :: FeedConfiguration
feedConfig = FeedConfiguration
    { feedTitle       = "Miguel Vilá"
    , feedDescription = "Miguel Vilá's personal blog"
    , feedAuthorName  = "Miguel Vilá"
    , feedRoot        = siteUrl
    }

-- https://groups.google.com/forum/#!searchin/hakyll/if$20class/hakyll/WGDYRa3Xg-w/nMJZ4KT8OZUJ 
activeClassField :: Context a 
activeClassField = functionField "activeClass" $ \[p] _ -> do 
    path <- toFilePath <$> getUnderlying 
    return $ if path == p then "active" else path 

--------------------------------------------------------------------------------
