{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DeriveDataTypeable #-}

module ServiceFabric.Timeout where

import Data.Typeable
import ServiceFabric.Types
import Control.Concurrent
import Control.Monad.IO.Class
import Control.Monad.CatchIO

data TimeoutOptions = TimeoutOptions {
  timeoutDescription  :: String,
  timeoutLimitMs      :: Int
}

defaultTimeoutOptions :: TimeoutOptions
defaultTimeoutOptions = TimeoutOptions { timeoutDescription = "Service call timed out.", timeoutLimitMs = 30000 }

data TimeoutException = TimeoutException String deriving (Eq, Show, Typeable)
instance Exception TimeoutException

-- Forking would result in the values within m being lost.
addTimeout :: (MonadCatchIO m) => TimeoutOptions -> BasicService m a b -> BasicService m a b
addTimeout options service = (\request -> do
  currentThreadId <- liftIO $ myThreadId
  timeoutThreadId <- liftIO $ forkIO $ do
                                          threadDelay (timeoutLimitMs options)
                                          throwTo currentThreadId (TimeoutException $ timeoutDescription options)
  finally (service request) (liftIO $ killThread timeoutThreadId))