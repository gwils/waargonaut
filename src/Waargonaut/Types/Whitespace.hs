module Waargonaut.Types.Whitespace where

import           Data.ByteString.Builder (Builder)
import qualified Data.ByteString.Builder as BB

import           Data.Foldable           (asum)
import           Data.Functor            ((<$))

import           Text.Parser.Char        (CharParsing, char, newline, tab)
import           Text.Parser.Combinators (many)

-- $setup
-- >>> :set -XOverloadedStrings
-- >>> import Control.Monad (return)
-- >>> import Data.Either(Either (..), isLeft)
-- >>> import Data.Digit (Digit(..))
-- >>> import qualified Data.Digit as D
-- >>> import Text.Parsec(ParseError)
-- >>> import Data.ByteString.Lazy (toStrict)
-- >>> import Data.ByteString.Builder (toLazyByteString)
-- >>> import Utils

-- ws =
  -- %x20 /              ; Space
  -- %x09 /              ; Horizontal tab
  -- %x0A /              ; Line feed or New line
  -- %x0D )              ; Carriage return
data Whitespace
  = Space
  | HorizontalTab
  | LineFeed
  | NewLine
  | CarriageReturn
  deriving (Eq, Ord, Show)

newtype WS = WS [Whitespace]
  deriving (Eq,  Show)

-- |
--
-- >>> testparse parseWhitespace " "
-- Right (WS [Space])
--
-- >>> testparse parseWhitespace " \t"
-- Right (WS [Space,HorizontalTab])
--
-- >>> testparse parseWhitespace "\f\f"
-- Right (WS [LineFeed,LineFeed])
--
-- >>> testparse parseWhitespace "\r\r\r"
-- Right (WS [CarriageReturn,CarriageReturn,CarriageReturn])
--
-- >>> testparse parseWhitespace "\n\r\r\n"
-- Right (WS [NewLine,CarriageReturn,CarriageReturn,NewLine])
--
-- >>> testparse parseWhitespace ""
-- Right (WS [])
--
parseWhitespace
  :: CharParsing f
  => f WS
parseWhitespace =
  fmap WS . many $ asum
    [ Space          <$ char ' '
    , HorizontalTab  <$ tab
    , LineFeed       <$ char '\f'
    , CarriageReturn <$ char '\r'
    , NewLine        <$ newline
    ]

unescapedWhitespaceChar :: Whitespace -> Char
unescapedWhitespaceChar Space          = ' '
unescapedWhitespaceChar HorizontalTab  = 't'
unescapedWhitespaceChar LineFeed       = 'f'
unescapedWhitespaceChar CarriageReturn = 'r'
unescapedWhitespaceChar NewLine        = 'n'
{-# INLINE unescapedWhitespaceChar #-}

escapedWhitespaceChar :: Whitespace -> Char
escapedWhitespaceChar Space          = ' '
escapedWhitespaceChar HorizontalTab  = '\t'
escapedWhitespaceChar LineFeed       = '\f'
escapedWhitespaceChar CarriageReturn = '\r'
escapedWhitespaceChar NewLine        = '\n'
{-# INLINE escapedWhitespaceChar #-}

whitespaceBuilder :: Whitespace -> Builder
whitespaceBuilder Space          = BB.charUtf8 ' '
whitespaceBuilder HorizontalTab  = BB.charUtf8 '\t'
whitespaceBuilder LineFeed       = BB.charUtf8 '\f'
whitespaceBuilder CarriageReturn = BB.charUtf8 '\r'
whitespaceBuilder NewLine        = BB.charUtf8 '\n'
{-# INLINE whitespaceBuilder #-}

wsBuilder :: WS -> Builder
wsBuilder (WS ws) = foldMap whitespaceBuilder ws
