{-# LANGUAGE CPP               #-}
{-# LANGUAGE OverloadedStrings #-}
-- | Wrappers for generating prologue and epilogue code in Haskell.
module Data.Aeson.AutoType.CodeGen.Haskell(
    writeHaskellModule
  , defaultHaskellFilename
  ) where

import qualified Data.Text           as Text
import qualified Data.Text.IO        as Text
import           Data.Text
import qualified Data.HashMap.Strict as Map
import           Control.Arrow               (first)
import           Data.Monoid                 ((<>))
import           System.FilePath
import           System.IO

import           Data.Aeson.AutoType.Format
import           Data.Aeson.AutoType.Type
import           Data.Aeson.AutoType.CodeGen.HaskellFormat
import           Data.Aeson.AutoType.Util

-- | Default output filname is used, when there is no explicit output file path, or it is "-" (stdout).
-- Default module name is consistent with it.
defaultHaskellFilename :: FilePath
defaultHaskellFilename = "JSONTypes.hs"

header :: Text -> Text
header moduleName = Text.unlines [
   "{-# LANGUAGE TemplateHaskell     #-}"
  ,"{-# LANGUAGE ScopedTypeVariables #-}"
  ,"{-# LANGUAGE RecordWildCards     #-}"
  ,"{-# LANGUAGE OverloadedStrings   #-}"
  ,"{-# LANGUAGE TypeOperators       #-}"
  ,"{-# LANGUAGE DeriveGeneric       #-}"
  ,""
  ,Text.concat ["module ", capitalize moduleName, " where"]
  ,""
  ,"import           System.Exit        (exitFailure, exitSuccess)"
  ,"import           System.IO          (stderr, hPutStrLn)"
  ,"import qualified Data.ByteString.Lazy.Char8 as BSL"
  ,"import           System.Environment (getArgs)"
  ,"import           Control.Monad      (forM_, mzero, join)"
  ,"import           Control.Applicative"
  ,"import           Data.Aeson.AutoType.Alternative"
  ,"import           Data.Aeson(decode, Value(..), FromJSON(..), ToJSON(..),"
#if MIN_VERSION_aeson(0,11,0)
  ,"                            pairs,"
#endif
  ,"                            (.:), (.:?), (.=), object)"
  ,"import           Data.Monoid"
  ,"import           Data.Text (Text)"
  ,"import qualified GHC.Generics" 
  ,""
  ,"-- | Workaround for https://github.com/bos/aeson/issues/287."
  ,"o .:?? val = fmap join (o .:? val)"
  ,""]

epilogue :: Text -> Text
epilogue toplevelName = Text.unlines
  [""
  ,"parse :: FilePath -> IO " <> toplevelName
  ,"parse filename = do input <- BSL.readFile filename"
  ,"                    case decode input of"
  ,"                      Nothing -> fatal $ case (decode input :: Maybe Value) of"
  ,"                                           Nothing -> \"Invalid JSON file: \"     ++ filename"
  ,"                                           Just v  -> \"Mismatched JSON value from file: \" ++ filename"
  ,"                      Just r  -> return (r :: " <> toplevelName <> ")"
  ,"  where"
  ,"    fatal :: String -> IO a"
  ,"    fatal msg = do hPutStrLn stderr msg"
  ,"                   exitFailure"
  ,""
  ,"main :: IO ()"
  ,"main = do"
  ,"  filenames <- getArgs"
  ,"  forM_ filenames (\\f -> parse f >>= (\\p -> p `seq` putStrLn $ \"Successfully parsed \" ++ f))"
  ,"  exitSuccess"
  ,""]

-- | Write a Haskell module to an output file, or stdout if `-` filename is given.
writeHaskellModule :: FilePath -> Text -> Map.HashMap Text Type -> IO ()
writeHaskellModule outputFilename toplevelName types =
    withFileOrHandle outputFilename WriteMode stdout $ \hOut -> do
      assertM (extension == ".hs")
      Text.hPutStrLn hOut $ header $ Text.pack moduleName
      -- We write types as Haskell type declarations to output handle
      Text.hPutStrLn hOut $ displaySplitTypes types
      Text.hPutStrLn hOut $ epilogue toplevelName
  where
    (moduleName, extension) =
       first normalizeTypeName'     $
       splitExtension               $
       if     outputFilename == "-"
         then defaultHaskellFilename
         else outputFilename
    normalizeTypeName' = Text.unpack . normalizeTypeName . Text.pack

