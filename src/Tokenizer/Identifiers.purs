module Tokenizer.Identifiers
    ( identifier
    , constant
    , rightParen 
    , leftParen
    , comma
    , lineComment
    , blockComment
    , functionArg
    , whiteSpace
    ) where 

import Data.Identity
import Prelude

import Control.Alt ((<|>))
import Control.Alt ((<|>))
import Data.Array as A
import Data.Either as E
import Data.List as L
import Data.Maybe (Maybe(..))
import Data.String.CodeUnits (fromCharArray)
import Text.Parsing.Parser as P
import Text.Parsing.Parser.Combinators as C
import Text.Parsing.Parser.String as S
import Text.Parsing.Parser.Token as PT
import Tokenizer.Tokens (Parser, TokenParser, Token(..))
import Tokenizer.Utilities as U





identifier :: TokenParser
identifier = do 
    first <- PT.letter
    remaining <- A.many $ C.try do 
        an <- C.optionMaybe $ C.try PT.alphaNum 
        res <- case an of 
            Just c -> pure c
            Nothing -> S.char '_'
        pure res    
    pure $ Identifier (fromCharArray $ A.concat [[first], remaining])

constant :: TokenParser
constant = do 
    first <- PT.digit
    remaining <- A.many $ C.try PT.digit
    pure $ Constant (fromCharArray $ A.concat [[first], remaining])

rightParen :: TokenParser
rightParen = do 
    _ <- S.string ")"
    pure $ RightParen

leftParen :: TokenParser
leftParen = do 
    _ <- S.string "("
    pure $ LeftParen

comma :: TokenParser 
comma = do 
    _ <- S.string ","
    pure $ Comma

lineComment :: TokenParser 
lineComment = do 
    _ <- S.string "--"
    maybe <- C.optionMaybe <<< C.try $ C.manyTill S.anyChar (S.char '\n')
    chars <- case maybe of 
            Just cs -> pure cs
            Nothing -> C.manyTill S.anyChar S.eof
    pure <<< LineComment <<< fromCharArray $ (A.fromFoldable chars)

blockComment :: TokenParser 
blockComment = do 
    _ <- S.string "/*"
    chars <- C.manyTill S.anyChar (S.string "*/")
    pure <<< BlockComment <<< fromCharArray $ (A.fromFoldable chars)

functionArg :: TokenParser
functionArg = do 
        C.try identifier
    <|> C.try constant

whiteSpace :: TokenParser
whiteSpace = do 
    _ <- U.whiteSpace
    pure WhiteSpace