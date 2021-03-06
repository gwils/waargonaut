{ mkDerivation, base, bytestring, containers, contravariant
, criterion, digit, directory, distributive, doctest, errors
, filepath, hedgehog, hoist-error, lens, mtl, nats, parsec, parsers
, scientific, semigroups, stdenv, tasty, tasty-expected-failure
, tasty-hedgehog, tasty-hunit, template-haskell, text, transformers
, vector, weigh, witherable, wl-pprint-annotated, zippers
}:
mkDerivation {
  pname = "waargonaut";
  version = "0.1.0.0";
  src = ./.;
  libraryHaskellDepends = [
    base bytestring containers contravariant digit distributive errors
    hoist-error lens mtl nats parsers scientific semigroups text
    transformers vector witherable wl-pprint-annotated zippers
  ];
  testHaskellDepends = [
    base bytestring digit directory doctest filepath hedgehog lens
    parsec semigroups tasty tasty-expected-failure tasty-hedgehog
    tasty-hunit template-haskell text vector zippers
  ];
  benchmarkHaskellDepends = [
    base criterion lens parsec text weigh
  ];
  description = "JSON Mangling";
  license = stdenv.lib.licenses.bsd3;
}
