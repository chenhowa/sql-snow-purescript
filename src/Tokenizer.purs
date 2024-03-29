module Tokenizer 
    ( tokenize
    , runToken
    --, subQuery
    , separators
    ) where 


import Data.Identity
import Prelude

import Control.Alt ((<|>))
import Data.Array as A
import Data.Either (Either(..))
import Data.Foldable (foldr)
import Data.List as L
import Data.Maybe (Maybe(..))
import Text.Parsing.Parser as P
import Text.Parsing.Parser.Combinators (try)
import Text.Parsing.Parser.Combinators as C
import Text.Parsing.Parser.String as S
import Tokenizer.Identifiers as I
import Tokenizer.Keywords as K
import Tokenizer.Operators as O
import Tokenizer.Tokens (TokenParser, InputStream, TokenStream, Token(..), Parser)
import Tokenizer.Utilities as U


tokenize :: InputStream -> Either P.ParseError TokenStream
tokenize input = 
    let Identity result = P.runParserT input tokens
    in result

runToken :: String -> Either P.ParseError Token
runToken str = 
    let Identity result = P.runParserT str token
    in result

token :: TokenParser 
token = (do try separatorToken <|> nonSeparatorToken )

separatorToken :: TokenParser
separatorToken = do 
        try I.whiteSpace
    <|> try I.comma
    <|> try I.leftParen
    <|> try I.rightParen
    <|> try I.lineComment
    <|> try I.blockComment

separators :: Parser
separators = do 
    s <- A.some <<< try $ separatorToken 
    pure s

tokens :: Parser 
tokens = do 
    initialSeps <- A.many $ try separatorToken
    ts <- (A.many (try do
        t <- nonSeparatorToken
        seps <- separators   -- read multiple separators
        pure $ [t] <> seps))
    let flatTs = A.concat ts 
    t <- C.optionMaybe (try nonSeparatorToken)  -- We need to use optionMaybe with try, because if the parse fails but consumes no input, 
    case t of                       -- what result is extracted into t? Nothing can be. Therefore the try basically is ignored,
        Nothing -> do               -- and the parse is regarded as having failed. Also, note that this section relies on
            S.eof                   -- 'maximum munch' being used. For example, if the input was "inner", but "in" was parsed before 
            pure $ A.concat [initialSeps, flatTs]    -- "inner", then "in" would match, and the parse for the EOF would fail, so the whole parse 
        Just last -> do             -- would fail.
            S.eof
            pure $ A.concat [initialSeps, flatTs, [last]]

nonSeparatorToken :: TokenParser
nonSeparatorToken = 
    let parsers = A.concat   -- these parsers have been ordered intentionally so that the "maximum munch" principle holds.
            [ joinParsers    -- that is, given the text "inner"m "inner" should be parsed instead of "in", so the `Inner` parser comes first.
            , setOpParsers   -- It would be nice if there were a better way to enforce 'maximum munch' (i.e., programmatically'), but 
            ,    [ K.distinct   -- it doesn't appear that there is such a way. I may have to revisit this in the future.
                , K.limit 
                , K.all
                , K.in_
                ]
            , orderParsers 
            , groupParsers
            , selectParsers
            ,   [ I.constant
                , K.as
                , K.wildcard
                ]
            , operatorParsers
            ]
    in foldr (<|>) I.identifier (try <$> parsers) -- identifier is intentionally last, since the earlier ones are higher in priority and need to match first

    where 
        joinParsers :: Array TokenParser 
        joinParsers = 
                    [ K.right 
                    , K.inner 
                    , K.outer 
                    , K.natural
                    , K.join 
                    , K.on
                    , K.left
                    ]

        operatorParsers :: Array TokenParser 
        operatorParsers = 
                    [ O.minus 
                    , O.multiply 
                    , O.floatDivide 
                    , O.modulo
                    , O.plus
                    , O.equals
                    , O.notEquals
                    , O.not 
                    , O.and
                    , O.or
                    , O.gte  -- gte and lte come first for maximum munch
                    , O.lte
                    , O.lt 
                    , O.gt 
                    ]

        orderParsers :: Array TokenParser 
        orderParsers = 
                    [ K.ascending 
                    , K.descending 
                    , K.orderBy
                    ]

        groupParsers :: Array TokenParser 
        groupParsers = 
                    [ K.having
                    , K.groupBy
                    ]

        setOpParsers :: Array TokenParser
        setOpParsers = 
                    [ K.intersect 
                    , K.union
                    ]

        selectParsers :: Array TokenParser 
        selectParsers = 
                    [ K.from 
                    , K.where_ 
                    , K.select
                    ]