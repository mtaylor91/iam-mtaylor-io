{-# LANGUAGE OverloadedStrings #-}
module IAM.Command.Server
  ( server
  , serverOptions
  , ServerOptions(..)
  ) where

import Control.Exception
import Data.ByteString (ByteString)
import Data.Text as T
import Data.Text.Encoding
import Options.Applicative
import System.Environment
import Text.Read

import IAM.Config
import IAM.Server.App
import IAM.Server.Context
import IAM.Server.DB
import IAM.Server.DB.InMemory
import IAM.Server.DB.Postgres
import IAM.Server.Init


data ServerOptions = ServerOptions
  { port :: !Int
  , postgres :: !Bool
  , migrations :: !FilePath
  } deriving (Show)


server :: ServerOptions -> IO ()
server opts = do
  if postgres opts
    then pgDB >>= startServer opts
    else inMemory >>= startServer opts
  where
    pgDB = do
      pgHost <- loadEnvConfig "POSTGRES_HOST"
      pgPort <- readEnvConfig "POSTGRES_PORT"
      pgDatabase <- loadEnvConfig "POSTGRES_DATABASE"
      pgUserName <- loadEnvConfig "POSTGRES_USER"
      pgPassword <- loadEnvConfig "POSTGRES_PASSWORD"
      connectToDatabase pgHost pgPort pgDatabase pgUserName pgPassword $ migrations opts


startServer :: DB db => ServerOptions -> db -> IO ()
startServer opts db = do
  adminEmail <- T.pack <$> configEmail
  adminPublicKey <- T.pack <$> configPublicKey
  host <- decodeUtf8 <$> loadEnvConfig "HOST"
  db' <- initDB host adminEmail adminPublicKey db
  startApp (port opts) host $ Ctx db'


serverOptions :: Parser ServerOptions
serverOptions = ServerOptions
  <$> option auto
      ( long "port"
     <> short 'p'
     <> metavar "PORT"
     <> help "Port to listen on"
     <> value 8080
     <> showDefault
      )
  <*> switch ( long "postgres"
      <> help "Use Postgres database"
      )
  <*> strOption
      ( long "migrations"
    <> metavar "DIRECTORY"
    <> help "Directory containing SQL migrations"
    <> value "/usr/local/share/iam-mtaylor-io/db"
    <> showDefault
      )


loadEnvConfig :: String -> IO ByteString
loadEnvConfig key = do
  maybeValue <- lookupEnv key
  case maybeValue of
    Nothing -> throw $ userError $ key ++ " environment variable not set"
    Just val -> return $ encodeUtf8 $ T.pack val


readEnvConfig :: Read t => String -> IO t
readEnvConfig key = do
  maybeValue <- lookupEnv key
  case maybeValue of
    Nothing -> throw $ userError $ key ++ " environment variable not set"
    Just val -> case readMaybe val of
      Nothing -> throw $ userError $ key ++ " environment variable not a valid value"
      Just val' -> return val'
