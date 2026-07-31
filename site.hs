--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Data.List (sortOn)
import           Hakyll
import           Hakyll.Web.Template.Context (getItemUTC)
import           Control.Applicative
import           Data.Time.Format (TimeLocale(..), defaultTimeLocale)
import           Data.Maybe
import           Data.Map (fromListWith, keys, (!))
import           Data.Time.Format (formatTime)
import           Data.Time.Clock (UTCTime)
import           Data.Ord (Down(..))

import           Text.Pandoc.Definition
import           Text.Pandoc.Shared
import           Text.Pandoc.Options
import           Text.Pandoc.Walk (walkM, walk)

import qualified Data.Map as M
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as LBS
import           Data.Word (Word8)
import           Data.Char (toLower)
import           System.FilePath (dropExtension, takeExtension)
-- NB: only the *type* `Image` is imported (no data constructor) so it does not
-- clash with Pandoc's `Image` inline constructor used in makeImagesResponsive.
import           Codec.Picture
                   ( Image, DynamicImage, PixelRGB8(..)
                   , decodeImage, convertRGB8
                   , generateImage, pixelAt, imageWidth, imageHeight )
import           Codec.Picture.Types (convertImage, pixelFold)
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

    nonPostPage "gifts-guide.md"

    nonPostPage "side-projects.md"

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            postsWithYears <- sortAndGroup <$> mapM (\post -> fmap (\timeInfo -> (year timeInfo, (date timeInfo, post))) (getTimeInfo $ itemIdentifier post)) posts
            let years = reverse $ keys postsWithYears
            let postsSortedRecentFirst = map snd . sortOn (Down . fst)
            let postsItemsWithYears = mapM makeItem $ fmap (\year -> (year, postsSortedRecentFirst (postsWithYears ! year))) years

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

nonPostPage name =
    create [ name ] $ do
        route (setExtension ".html")
        compile $ responsiveImagesCompiler
            >>= loadAndApplyTemplate "templates/default.html" siteCtx
            >>= relativizeUrls

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
postCtxWithTags tags = tagsField "tags" tags `mappend` postCtx

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
