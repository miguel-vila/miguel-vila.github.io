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

--------------------------------------------------------------------------------
-- Used to specify whether to take all or some of an item list
data ItemCount = All | Only Int
--------------------------------------------------------------------------------

siteUrl = "http://miguel-vila.github.io"

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

main :: IO ()
main = hakyll $ do
    serveFilesAt "images/*"
    serveFilesAt "images/**/*"
    serveFilesAt "code/*"
    serveFilesAt "scripts/*"
    serveFilesAt "assets/*"
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
                      `mappend` activeClassField 
                      `mappend` defaultContext 
            makeItem "" 
                >>= loadAndApplyTemplate "templates/tag.html" ctx 
                >>= loadAndApplyTemplate "templates/default.html" ctx 
                >>= relativizeUrls

    let tagsPostCtx = postCtxWithTags tags
    match "drafts/*" $ do
        route $ setExtension "html"
        compile $ pandocCompiler
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

    match "posts/*" $ do
        route $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/post.html"    tagsPostCtx
            >>= saveSnapshot "content"
            >>= loadAndApplyTemplate "templates/disqus.html"  tagsPostCtx
            >>= loadAndApplyTemplate "templates/default.html" tagsPostCtx
            >>= relativizeUrls

    create ["side-projects.html"] $ do
        route idRoute
        let sideProjectsCtx =
                    constField "title" "Side Projects" `mappend`
                    siteCtx
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" sideProjectsCtx
            >>= relativizeUrls

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
                    constField "title" "Hi, there!"              `mappend`
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
draftCtx :: Context String
draftCtx = defaultContext `mappend` activeClassField

postCtx :: Context String
postCtx =
    dateField "date" "%b %d %Y" `mappend`
    dateField "simpleDate" "%b %d" `mappend`
    siteCtx

siteCtx :: Context String
siteCtx = 
    activeClassField `mappend`
    defaultContext

postCtxWithTags :: Tags -> Context String 
postCtxWithTags tags = tagsField "tags" tags `mappend` postCtx

feedConfig :: FeedConfiguration
feedConfig = FeedConfiguration
    { feedTitle       = "Miguel Vilá"
    , feedDescription = "Miguel Vilá's personal blog"
    , feedAuthorName  = "Miguel Vilá"
    , feedAuthorEmail = "miguelvilag@gmail.com"
    , feedRoot        = siteUrl
    }

-- https://groups.google.com/forum/#!searchin/hakyll/if$20class/hakyll/WGDYRa3Xg-w/nMJZ4KT8OZUJ 
activeClassField :: Context a 
activeClassField = functionField "activeClass" $ \[p] _ -> do 
    path <- toFilePath <$> getUnderlying 
    return $ if path == p then "active" else path 
