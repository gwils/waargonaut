{-# LANGUAGE OverloadedStrings #-}
module Main where

import           Control.Lens                (( # ), (^.), (^?), _2)
import qualified Control.Lens                as L

import           Data.Either                 (isLeft)

import           Data.ByteString             (ByteString)
import qualified Data.ByteString.Builder     as BB
import qualified Data.ByteString.Char8       as BS8
import qualified Data.ByteString.Lazy.Char8  as BSL8

import           Data.Maybe                  (fromMaybe)
import           Data.Semigroup              ((<>))
import           Data.Text                   (Text)
import qualified Data.Text.Encoding          as Text

import           Hedgehog
import qualified Hedgehog.Gen                as Gen
import qualified Hedgehog.Range              as Range
import           Text.Parsec                 (ParseError)

import           Test.Tasty
import           Test.Tasty.Hedgehog
import           Test.Tasty.HUnit

import           Data.Digit                  (Digit)

import           Waargonaut                  (Json)
import qualified Waargonaut                  as W
import qualified Waargonaut.Types.CommaSep   as CommaSep
import qualified Waargonaut.Types.JChar      as JChar
import qualified Waargonaut.Types.JString    as JString
import qualified Waargonaut.Types.Whitespace as WS

import qualified Types.CommaSep              as CS
import qualified Types.JChar                 as JC
import qualified Types.Json                  as J
import qualified Types.Whitespace            as WS

import qualified Utils

import qualified Decoder
import qualified Encoder

encodeText
  :: Json
  -> Text
encodeText =
  Text.decodeUtf8 .
  encodeByteString

encodeByteString
  :: Json
  -> ByteString
encodeByteString =
  BSL8.toStrict .
  BB.toLazyByteString .
  W.waargonautBuilder WS.wsBuilder

decode
  :: Text
  -> Either ParseError Json
decode =
  Utils.testparse W.parseWaargonaut

prop_uncons_consCommaSep :: Property
prop_uncons_consCommaSep = property $ do
  cs <- forAll $ CS.genCommaSeparated WS.genWS Gen.bool
  let
    elems = (^. CommaSep._CommaSeparated . _2)

    cs' = do
      (e,xs) <- CommaSep.unconsCommaSep cs
      let trailing = fromMaybe (CommaSep.Comma, mempty) (fst e)
      elems $ CommaSep.consCommaSep (trailing, snd e) xs

  elems cs === cs'

prop_uncons_consCommaSepVal :: Property
prop_uncons_consCommaSepVal = property $ do
  cs <- forAll $ CS.genCommaSeparated WS.genEmptyWS Gen.bool
  let
    elems = (^. CommaSep._CommaSeparated . _2)

  elems cs === (elems . uncurry L.cons =<< L.uncons cs)

prop_jcharescaped_hex_prism :: Property
prop_jcharescaped_hex_prism = property $ do
  a <- forAll JC.genHex4Lower
  -- Doesn't preserve the upper/lower case of the Hex values. Acceptable?
  Just a === ((((JChar._Hex # a) :: Char) ^? JChar._Hex) :: Maybe (JChar.HexDigit4 Digit))

prop_jstring_text :: Property
prop_jstring_text = property $ do
  t <- forAll $ Gen.text (Range.linear 0 1000) Gen.unicodeAll
  Just t === ((JString._JStringText # t) ^? JString._JStringText)

prop_jchar :: Property
prop_jchar = property $ do
  c <- forAll Gen.unicodeAll
  Just c === ((JChar._JChar #) <$> (c ^? JChar._JChar))

prop_tripping :: Property
prop_tripping = withTests 200 . property $
  forAll J.genJson >>= (\j -> tripping j encodeText decode)

prop_print_parse_print_id :: Property
prop_print_parse_print_id = withTests 200 . property $ do
  printedA <- forAll $ encodeText <$> J.genJson
  Right printedA === (encodeText <$> decode printedA)

prism_properties :: TestTree
prism_properties = testGroup "Round trip some prisms"
  [ testProperty "CommaSeparated: cons . uncons = id" prop_uncons_consCommaSep
  , testProperty "CommaSeparated (disregard WS): cons . uncons = id" prop_uncons_consCommaSepVal
  , testProperty "HexDigit4 Digit -> Char -> HexDigit4 Digit = Just id" prop_jcharescaped_hex_prism
  , testProperty "Char -> JChar Digit -> Maybe Char = Just id" prop_jchar
  , testProperty "Text -> Maybe JString -> Maybe Text = Just id" prop_jstring_text
  ]

parser_properties :: TestTree
parser_properties = testGroup "Parser Round-Trip"
  [ testProperty "parse . print = id" prop_tripping
  , testProperty "print . parse . print = print" prop_print_parse_print_id
  ]

parsePrint :: ByteString -> Either ParseError ByteString
parsePrint = fmap encodeByteString . decode . Text.decodeUtf8

testFile :: FilePath -> Assertion
testFile fp = do
  s <- BS8.readFile fp
  parsePrint s @?= Right s

testFileFailure :: FilePath -> Assertion
testFileFailure fp = do
  s <- BS8.readFile fp
  assertBool (fp <> " should fail to parse!") (isLeft $ parsePrint s)

unitTests :: TestTree
unitTests =
  testGroup "File Tests - (print . parse = id)" (toTest <$> fs)
  where
    toTest f = testCase f (testFile f)

    fs =
      [ "test/json-data/test1.json"
      , "test/json-data/test2.json"
      , "test/json-data/test3.json"
      , "test/json-data/test5.json"
      , "test/json-data/test7.json"
      , "test/json-data/twitter100.json"
      , "test/json-data/jp100.json"
      ]

regressionTests :: TestTree
regressionTests = testGroup
  "Regression Tests - Failure to parse = Success"
  (toTestFail <$> fs)
  where
    toTestFail (dsc, f) =
      testCase dsc (testFileFailure f)

    fs =
      [ ("[11 12 13] (test4.json)","test/json-data/test4.json")
      , ("{\"foo\":3\"bar\":4} (test6.json)", "test/json-data/test6.json")
      ]

main :: IO ()
main = defaultMain $ testGroup "Waargonaut All Tests"
  [ parser_properties
  , prism_properties
  , unitTests
  , regressionTests

  , Decoder.decoderTests
  , Encoder.encoderTests
  ]
