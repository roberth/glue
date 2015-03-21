{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Glue.Caching(
    cacheWith
  , cacheWithAtomicLRU
) where

import Glue.Types
import Data.Cache.LRU.IO
import qualified Data.Cache.LRU.IO as LRU
import Control.Monad.IO.Class

-- Values within m will be lost for calls that hit the cache.
cacheWith :: (MonadIO m) => (a -> m (Maybe b)) -> (a -> b -> m ()) -> BasicService m a b -> BasicService m a b
cacheWith lookupWith insertWith service = 
  let fallback request = do
                            result <- service request
                            insertWith request result
                            return result 
      cachedService request = do
                                fromLookup <- lookupWith request
                                maybe (fallback request) return fromLookup
  in cachedService

cacheWithAtomicLRU :: (MonadIO m, Ord a) => AtomicLRU a b -> BasicService m a b -> BasicService m a b
cacheWithAtomicLRU lru service = 
  let lookupWith request            = liftIO $ LRU.lookup request lru
      insertWith request response   = liftIO $ insert request response lru
  in  cacheWith lookupWith insertWith service