{-# LANGUAGE DeriveGeneric #-}

module Main where

import qualified Data.ByteString.Lazy as B
import Control.Applicative
import Data.Aeson
import Data.Aeson.Types
import Data.Text
import GHC.Generics


jsonFile :: FilePath
jsonFile = "resources/ast.json"

getAstString :: IO B.ByteString
getAstString = B.readFile jsonFile

data Element = Literal Text deriving (Show, Generic)
data Identifier = Identifier Text deriving (Show, Generic)
data Argument = ElementArgument Element
              | IdentifierArgument Identifier
              | ExpressionArgument Expression
              | UnknownArgument Text
              deriving (Show, Generic)
data Expression = CallExpression Identifier [Argument]
                | ArrayExpression [Argument]
                | FunctionExpression [Identifier] Statement
                | UnknownExpression Text
                deriving (Show, Generic)
data Statement = ExpressionStatement Expression
               | BlockStatement [Statement]
               | ReturnStatement Expression
               | UnknownStatement Text
               deriving (Show, Generic)
data Program = Program [Statement] deriving (Show, Generic)


selectArgument :: Object -> Parser Argument
selectArgument x = (IdentifierArgument <$> selectIdentifier x)
  <|> (ElementArgument <$> selectElement x)
  <|> (ExpressionArgument <$> selectExpression x)
  <|> (UnknownArgument <$> x .: pack "type")

makeCall x = CallExpression <$> x .: pack "callee" <*> x .: pack "arguments"
makeArray x = ArrayExpression <$> x .: pack "elements"
makeFunction x = FunctionExpression <$> x .: pack "params" <*> x .: pack "body"
makeUnknown x = UnknownExpression <$> x .: pack "type"

selectExpression :: Object -> Parser Expression
selectExpression x = makeCall x
  <|> makeArray x
  <|> makeFunction x
  <|> makeUnknown x

makeExpressionStatement x = ExpressionStatement <$> x .: pack "expression"
makeBlockStatement x = BlockStatement <$> x .: pack "body"
makeReturnStatement x = ReturnStatement <$> x .: pack "argument"
unknownStatement x = UnknownStatement <$> x .: pack "type"

selectStatement :: Object -> Parser Statement
selectStatement x = makeExpressionStatement x
    <|> makeBlockStatement x
    <|> makeReturnStatement x
    <|> unknownStatement x

selectElement :: Object -> Parser Element
selectElement x = Literal <$> x .: pack "value"

selectIdentifier :: Object -> Parser Identifier
selectIdentifier x = Identifier <$> x .: pack "name"

instance FromJSON Argument where
  parseJSON (Object x) = selectArgument x
  parseJSON _ = fail "expected Object"

instance ToJSON Argument where
  toJSON = genericToJSON defaultOptions

instance FromJSON Element where
  parseJSON (Object x) = selectElement x
  parseJSON _ = fail "Expected Object"

instance ToJSON Element where
  toJSON = genericToJSON defaultOptions

instance FromJSON Identifier where
  parseJSON (Object x) = selectIdentifier x
  parseJSON _ = fail "Expected Object"

instance ToJSON Identifier where
  toJSON = genericToJSON defaultOptions

instance FromJSON Statement where
  parseJSON (Object x) = selectStatement x
  parseJSON _ = fail "Expected Object"

instance ToJSON Statement where
  toJSON = genericToJSON defaultOptions

instance FromJSON Expression where
  parseJSON (Object x) = selectExpression x
  parseJSON x = fail $ show x

instance ToJSON Expression where
  toJSON = genericToJSON defaultOptions

instance FromJSON Program where
  parseJSON (Object x) = Program <$> x .: pack "body"
  parseJSON _ = fail "Expected Object"

instance ToJSON Program where
  toJSON = genericToJSON defaultOptions



run :: IO (Either String Program)
run = eitherDecode <$> getAstString

main :: IO ()
main = do
  d <- run
  case d of
    Left err -> putStrLn err
    Right ps -> print ps