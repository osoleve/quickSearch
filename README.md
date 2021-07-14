Name-QuickSearch
---

A tool for quickly locating the most likely match
for a name (or other short natural language string) in another (very large) set of names.

Use case for which it was developed: You need to match records across two data
sets using only names, but have too many records to reasonably
perform string distance calculations between every pair in the cartesian set.
QuickSearch only performs distance calculations between strings
that share an entire token, making it well suited to quickly remove the low-hanging
fruit. This in turn drastically reduces the sizes of the sets requiring a
costly full scan, allowing for more iteration and experimentation on the edge cases.

On my machine, in ghci, QuickSearch can retrieve the best matches for a string
from a population of 100,000 strings in an average of ~0.02 seconds.

Uses `Data.Text` internally, but there is an identical `String` interface
to be found at `QuickSearch.String` if that suits the pipeline better.

Usage:

```haskell
> import QuickSearch

> names = map T.pack ["Rep. Meg Mueller","Twana Jacobs",...,"Sammie Paucek"]

> entries = zip names [1..] --Stand-in for your UIDs

> qs = buildQuickSearch entries

-- Scorer can be any func of type (T.Text -> T.Text -> Ratio Int)
> target = pack "Rep. Meg Muller"
> getTopMatches 1 target qs jaroWinkler
[(100,("Rep. Meg Mueller",1))]

> target = pack "Towana Jacobs"
> getMatchesWithCutoff 90 target qs damerauLevenshteinNorm
[(92,("Twana Jacobs",2))]
```

## Batch Usage

If you have your list of names to be matched and list of target names both
in the form `[(T.Text, Int)]`, you can run it in batch mode with

```haskell
names, targets :: [(T.Text, Int)]
scorer :: (T.Text -> T.Text -> Ratio Int)
scorer = damerauLevenshteinNorm

> oneShotBatchProcess names targets scorer
```
which will return a list of `(entry, (score, target))`, where `target` is the
found name and its UID.

Able to process thousands of names against a population of
a hundred thousand names in under a second (on average... first search always
takes several seconds to build the filters).

Shout out to Charles Sommers, who wrote the original tool I'm porting to Haskell.