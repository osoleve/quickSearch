{-# LANGUAGE ViewPatterns #-}

module QuickSearch.String
  ( buildQuickSearch
  , topNMatches
  , matchesWithThreshold
  , batch
  , batchTopNMatches
  , batchMatchesWithThreshold
  , Token
  , Score
  , Scorer
  , SEntry(..)
  , Scored
  , QuickSearch(..)
  )
where

import           Control.Arrow            hiding (first, second)
import           Data.Hashable
import           Data.Ratio
import qualified Data.Text                 as T
import           Data.Text.Metrics         (damerauLevenshteinNorm, jaro,
                                            jaroWinkler)

import           QuickSearch               (Entry(..))
import           QuickSearch.Filter        hiding (first, second)
import           QuickSearch.MatchAndScore

data SEntry uid = SEntry {
    sEntryName :: String
  , sEntryUID  :: uid
} deriving (Show)

first :: (String -> String) -> SEntry uid -> SEntry uid
first f entry = SEntry (f . sEntryName $ entry) (sEntryUID entry)

stringEntryToEntry :: (Hashable uid, Eq uid) => SEntry uid -> Entry uid
stringEntryToEntry = uncurry Entry . (T.pack . sEntryName &&& sEntryUID)

entryToStringEntry :: (Hashable uid, Eq uid) => Entry uid -> SEntry uid
entryToStringEntry = uncurry SEntry . (T.unpack . entryName &&& entryUID)

-- | Given a Scored (SEntry uid), return it as a Scored (Entry uid)
scoredStringToText
  :: (Hashable uid, Eq uid)
  => Scored (SEntry uid)
  -> Scored (Entry uid)
scoredStringToText scoredSEntry = Scored score textEntry
  where
    (score, entry) = (scoredScore &&& scoredEntry) scoredSEntry
    textEntry = stringEntryToEntry entry

-- | Given a Scored (SEntry uid), return it as a Scored (Entry uid)
scoredTextToString
  :: (Hashable uid, Eq uid)
  => Scored (Entry uid)
  -> Scored (SEntry uid)
scoredTextToString scoredSEntry = Scored score textEntry
  where
    (score, entry) = (scoredScore &&& scoredEntry) scoredSEntry
    textEntry = entryToStringEntry entry

-- | Given a list of entries to be searched, create a QuickSearch object.
rawBuildQuickSearch
  :: (Hashable uid, Eq uid)
  => [SEntry uid] -- ^ List of entries to be searched
  -> QuickSearch uid -- ^ QuickSearch object holding token partitions
rawBuildQuickSearch entries =
  let stringToText = T.pack . sEntryName
      entries' = map stringEntryToEntry entries
      tokenFilter = buildTokenPartitions entries'
  in  QuickSearch entries' tokenFilter

-- | Given a list of pairs of (String, uid) to be searched,
-- create a QuickSearch object.
buildQuickSearch
  :: (Hashable uid, Eq uid)
  => [(String, uid)] -- ^ List of entries to be searched
  -> QuickSearch uid -- ^ QuickSearch object holding token partitions
buildQuickSearch entries =
  let entries' = map (stringEntryToEntry . uncurry SEntry) entries
      tokenFilter = buildTokenPartitions entries'
  in  QuickSearch entries' tokenFilter

-- | Given a QuickSearch object, scorer, and string, return the top N matches.
topNMatches
  :: (Hashable uid, Eq uid)
  => QuickSearch uid -- ^ QuickSearch object holding token partitions
  -> Int -- ^ N: Number of results to return
  -> Scorer -- ^ String similarity function of type (Text -> Text -> Ratio Int)
  -> String -- ^ String to be searched
  -> [Scored (SEntry uid)] -- ^ Top N most similar entries
topNMatches qs n scorer (T.pack -> entry) = map scoredTextToString results
  where
    results = take n (scoreMatches entry qs scorer)

-- | Given a QuickSearch object, scorer, and string, return all matches with a
-- score greater than the given threshold.
matchesWithThreshold
  :: (Hashable uid, Eq uid)
  => QuickSearch uid -- ^ QuickSearch object holding token partitions
  -> Int -- ^ Threshold score above which to return results
  -> Scorer -- ^ String similarity function of type (Text -> Text -> Ratio Int)
  -> String -- ^ String to be searched
  -> [Scored (SEntry uid)] -- ^ Top N most similar entries
matchesWithThreshold qs cutoff scorer (T.pack -> entry) = map scoredTextToString results
  where results             = scoreMatches entry qs scorer

-- | Turn a match retrieval function into one that works on lists of entries.
batch
  :: (Hashable uid1, Eq uid1, Hashable uid2, Eq uid2)
  => (QuickSearch uid2 -> Int -> Scorer -> String -> [Scored (SEntry uid2)])
  -- ^ A match retrieval function, such as topNMatches
  -> QuickSearch uid2 -- ^ QuickSearch object holding token partitions
  -> Int -- ^ The reference number for the match retrieval function.
         -- N for topNMatches, threshold for matchesWithThreshold
  -> Scorer -- ^ String similarity function of type (Text -> Text -> Ratio Int)
  -> [SEntry uid1] -- ^ List of entries to be processed
  -> [(SEntry uid1, [Scored (SEntry uid2)])]
  -- ^ List of entries and the results returned for each.
batch f qs n scorer entries =
  let results = map (f qs n scorer . sEntryName) entries in zip entries results

-- | Version of topNMatches that processes lists of entries instead of strings.
batchTopNMatches
  :: (Hashable uid1, Eq uid1, Hashable uid2, Eq uid2)
  => QuickSearch uid2 -- ^ QuickSearch object holding token partitions
  -> Int -- ^ N: Number of results to return
  -> Scorer -- ^ String similarity function of type (Text -> Text -> Ratio Int)
  -> [SEntry uid1] -- ^ List of entries to be processed
  -> [(SEntry uid1, [Scored (SEntry uid2)])]
  -- ^ List of entries and up to the top N matches for each.
batchTopNMatches = batch topNMatches

-- | Version of matchesWithThreshold that processes lists of entries instead of strings.
batchMatchesWithThreshold
  :: (Hashable uid1, Eq uid1, Hashable uid2, Eq uid2)
  => QuickSearch uid2 -- ^ QuickSearch object holding token partitions
  -> Int -- ^ N: Number of results to return
  -> Scorer -- ^ String similarity function of type (Text -> Text -> Ratio Int)
  -> [SEntry uid1] -- ^ List of entries to be processed
  -> [(SEntry uid1, [Scored (SEntry uid2)])]
  -- ^ List of entries and their matches above the score threshold.
batchMatchesWithThreshold = batch matchesWithThreshold
