--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Hakyll
import           Control.Applicative
import           Data.Time.Format (TimeLocale(..), defaultTimeLocale)
import           Data.Maybe

import           Text.Pandoc.Definition
import           Text.Pandoc.Shared
import           Text.Pandoc.Options

--------------------------------------------------------------------------------
-- Used to specify whether to take all or some of an item list
data ItemCount = All | Only Int
--------------------------------------------------------------------------------

siteUrl = "http://miguel-vila.github.io"

maybeTake :: ItemCount -> [a] -> [a]
maybeTake All  = id
maybeTake (Only n) = take n

takeRecentFirst n = fmap (maybeTake n) . recentFirst

--------------------------------------------------------------------------------

main :: IO ()
main = hakyll $ do
    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    -- build up tags 
    tags <- buildTags "posts/*" (fromCapture "tags/*.html")
    tagsRules tags $ \tag pattern -> do 
        let title = "Posts tagged \"" ++ tag ++ "\"" 
        route idRoute 
        compile $ do 
            posts <- recentFirst =<< loadAll pattern 
            let ctx = constField "title" title 
                      `mappend` listField "posts" postCtx (return posts) 
                      `mappend` activeClassField 
                      `mappend` defaultContext 
            makeItem "" 
                >>= loadAndApplyTemplate "templates/tag.html" ctx 
                >>= loadAndApplyTemplate "templates/default.html" ctx 
                >>= relativizeUrls

    match "posts/*" $ do
        route $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/post.html"    postCtx
            >>= saveSnapshot "content"
            >>= loadAndApplyTemplate "templates/disqus.html"  postCtx
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let archiveCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Archives"            `mappend`
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
                    constField "title" "Inicio"              `mappend`
                    siteCtx

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateCompiler

    create ["blog/atom.xml"] $ do
        route   $ idRoute
        compile $ do
          let feedCtx = postCtx `mappend` bodyField "description"
          posts <- takeRecentFirst (Only 5) =<< loadAllSnapshots "posts/*" "content"
          renderAtom feedConfig feedCtx posts

--------------------------------------------------------------------------------
postCtx :: Context String
postCtx =
    dateFieldWith esTimeLocale "date" "%B %e de %Y" `mappend`
    siteCtx

siteCtx :: Context String
siteCtx = 
    activeClassField `mappend`
    defaultContext

postCtxWithTags :: Tags -> Context String 
postCtxWithTags tags = tagsField "tags" tags `mappend` postCtx

esTimeLocale :: TimeLocale 
esTimeLocale =  TimeLocale { 
  wDays  = [("domingo", "dom"), ("lunes",     "lun"), 
            ("martes",  "mar"), ("miercoles", "mie"), 
            ("jueves",  "jue"), ("viernes",   "vie"), 
            ("sábado",  "sab")], 

  months = [("Enero",      "ene"), ("Febrero",  "feb"), 
            ("Marzo",      "mar"), ("Abril",    "abr"), 
            ("Mayo",       "may"), ("Junio",    "jun"), 
            ("Julio",      "jul"), ("Agosto",    "ago"), 
            ("Septiembre", "sep"), ("Octubre",  "oct"), 
            ("Noviembre",  "nov"), ("Diciembre", "dic")], 
{--
  intervals = [ ("año","años") 
              , ("mes", "meses") 
              , ("día","días") 
              , ("hora","horas") 
              , ("min","mins") 
              , ("seg","segs") 
              , ("useg","usegs") 
              ], 
--}
  amPm = (" de la mañana", " de la tarde"), 
  dateTimeFmt = "%a %e %b %Y, %H:%M:%S %Z", 
  dateFmt   = "%d/%m/%Y", 
  timeFmt   = "%H:%M:%S", 
  time12Fmt = "%I:%M:%S %p",
  knownTimeZones = knownTimeZones defaultTimeLocale
}

feedConfig :: FeedConfiguration
feedConfig = FeedConfiguration
    { feedTitle       = "Miguel Vilá"
    , feedDescription = "Blog personal de Miguel Vilá"
    , feedAuthorName  = "Miguel Vilá"
    , feedAuthorEmail = "miguelvilag@gmail.com"
    , feedRoot        = siteUrl
    }

-- https://groups.google.com/forum/#!searchin/hakyll/if$20class/hakyll/WGDYRa3Xg-w/nMJZ4KT8OZUJ 
activeClassField :: Context a 
activeClassField = functionField "activeClass" $ \[p] _ -> do 
    path <- toFilePath <$> getUnderlying 
    return $ if path == p then "active" else path 
