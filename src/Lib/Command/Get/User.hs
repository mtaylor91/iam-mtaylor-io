module Lib.Command.Get.User
  ( Lib.Command.Get.User.getUser
  ) where

import Data.Aeson
import Data.ByteString.Lazy (toStrict)
import Data.Text (Text)
import Data.Text.Encoding
import Network.HTTP.Client
import Network.HTTP.Client.TLS
import Network.HTTP.Types.Status
import Servant.Client
import qualified Data.Text as T

import Lib.Client
import Lib.Client.Auth
import Lib.Config
import Lib.IAM (UserId(..))


getUser :: Maybe Text -> IO ()
getUser = maybe getCurrentUser getUser'


getCurrentUser :: IO ()
getCurrentUser = do
  auth <- clientAuthInfo
  mgr <- newManager tlsManagerSettings { managerModifyRequest = clientAuth auth }
  url <- serverUrl
  result <- runClientM Lib.Client.getCaller $ mkClientEnv mgr url
  case result of
    Right user ->
      putStrLn $ T.unpack (decodeUtf8 $ toStrict $ encode $ toJSON user)
    Left err ->
      putStrLn $ "Error: " ++ show err


getUser' :: Text -> IO ()
getUser' email = do
  auth <- clientAuthInfo
  mgr <- newManager tlsManagerSettings { managerModifyRequest = clientAuth auth }
  url <- serverUrl
  let userClient = mkUserClient $ UserEmail email
  result <- runClientM (Lib.Client.getUser userClient) $ mkClientEnv mgr url
  case result of
    Right user ->
      putStrLn $ T.unpack (decodeUtf8 $ toStrict $ encode $ toJSON user)
    Left (FailureResponse _ response) ->
      case responseStatusCode response of
        s | s == status401 ->
          putStrLn "Unauthorized"
        s | s == status403 ->
          putStrLn "Forbidden"
        s | s == status404 ->
          putStrLn $ "User not found: " ++ T.unpack email
        _anyOtherStatus ->
          putStrLn "Unknown failure"
    Left err ->
      putStrLn $ "Error: " ++ show err


serverUrl :: IO BaseUrl
serverUrl = parseBaseUrl =<< configURL
