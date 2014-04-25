{-# LANGUAGE DeriveDataTypeable, TemplateHaskell #-}
{-# OPTIONS_GHC -F -pgmFderive -optF-F #-}
module Data.Aeson.AutoType.Type(typeSize,
                                Dict(..), keys, get,
                                Type(..), emptyType,
                                isSimple, isArray, isObject, typeAsSet) where

import           Control.Lens.TH
import qualified Data.ByteString.Lazy.Char8 as BSL
import qualified Data.HashMap.Strict as Hash
import qualified Data.Set            as Set
import qualified Data.Vector         as V
import           Data.Data          (Data(..))
import           Data.Typeable      (Typeable(..))
import           Data.Aeson
import           Data.Aeson.Types
import           Data.Text          (Text)
import           Data.Set           (Set )
import           Data.HashMap.Strict(HashMap)
import           Data.List          (sort, foldl1')
import           Data.Ord           (Ord(..), comparing)
import           Data.DeriveTH
import           Data.Derive.UniplateDirect

-- | Type alias for HashMap
type Map = HashMap

-- * Dictionary of types indexed by names.
newtype Dict = Dict { unDict :: Map Text Type }
  deriving (Show, Eq, Data, Typeable)

instance Ord Dict where
  compare = comparing $ sort . Hash.toList . unDict

-- | Take all keys from dictionary.
keys :: Dict -> Set Text
keys = Set.fromList . Hash.keys . unDict

-- * Type
data Type = TNull | TBool | TNum | TString |
            TUnion (Set.Set      Type)     |
            TLabel Text                    |
            TObj   Dict                    |
            TArray Type
  deriving (Show,Eq, Ord, Data, Typeable)

-- | Empty type
emptyType :: Type
emptyType = TUnion Set.empty 

-- | Lookup the Type within the dictionary.
get :: Text -> Dict -> Type
get key = Hash.lookupDefault emptyType key . unDict 

-- $derive makeUniplateDirect ''Type

-- | Size of the `Type` term.
typeSize TNull      = 1
typeSize TBool      = 1
typeSize TNum       = 1
typeSize TString    = 1
typeSize (TObj   o) = (1+) . sum     . map typeSize . Hash.elems . unDict $ o
typeSize (TArray a) = 1 + typeSize a
typeSize (TUnion u) = (1+) . maximum . (0:) . map typeSize . Set.toList $ u

typeAsSet t@(TUnion s) = s
typeAsSet t            = Set.singleton t

-- | Is the top-level constructor a TObj?
isObject (TObj _) = True
isObject _        = False

-- | Is it a simple (non-compound) Type?
isSimple x = not (isObject x) && not (isArray x) && not (isUnion x)

-- | Is the top-level constructor a TUnion?
isUnion (TUnion _) = True
isUnion _          = False

-- | Is the top-level constructor a TArray?
isArray (TArray _) = True
isArray _          = False
