{-# LANGUAGE MultiParamTypeClasses #-}
module Test.Validity
    ( module Data.GenValidity
    , Proxy(Proxy)

    -- * Tests for Arbitrary instances involving Validity
    , arbitrarySpec
    , arbitraryGeneratesOnlyValid
    , shrinkProducesOnlyValids

    -- * Tests for GenValidity instances
    , genValiditySpec
    , genValidityValidGeneratesValid
    , genValidityInvalidGeneratesInvalid

    -- * Tests for RelativeValidity instances
    , relativeValiditySpec
    , relativeValidityImpliesValidA
    , relativeValidityImpliesValidB

    -- * Tests for GenRelativeValidity instances
    , genRelativeValiditySpec
    , genRelativeValidityValidGeneratesValid
    , genRelativeValidityInvalidGeneratesInvalid

    -- * Standard tests involving validity
    , producesValidsOnGen
    , alwaysProducesValid
    , producesValidsOnValids
    , producesValidsOnGens2
    , alwaysProducesValid2
    , producesValidsOnValids2

    -- * Standard tests involving functions that can fail

    , CanFail(..)
    , succeedsOnGen
    , succeedsOnValidInput
    , failsOnGen
    , failsOnInvalidInput
    , validIfSucceedsOnGen
    , validIfSucceeds
    , succeedsOnGens2
    , succeedsOnValidInput2
    , failsOnGens2
    , failsOnInvalidInput2
    , validIfSucceedsOnGens2
    , validIfSucceeds2
    ) where

import           Data.Proxy
import           Data.Data

import           Data.GenValidity
import           Data.GenRelativeValidity

import           Test.Hspec
import           Test.QuickCheck

-- | A @Spec@ that specifies that @arbitrary@ only generates data that
-- satisfy @isValid@ and that @shrink@ only produces data that satisfy
-- @isValid@.
--
-- Example usage:
--
-- > arbitrarySpec (Proxy :: Proxy MyData)
arbitrarySpec
    :: (Typeable a, Show a, Validity a, Arbitrary a)
    => Proxy a
    -> Spec
arbitrarySpec proxy = do
    let name = nameOf proxy
    describe ("Arbitrary " ++ name) $ do
        it ("is instantiated such that 'arbitrary' only generates valid \'"
            ++ name
            ++ "\'s") $
            arbitraryGeneratesOnlyValid proxy

        it ("is instantiated such that 'shrink' only produces valid \'"
            ++ name
            ++ "\'s") $ do
            forAll arbitrary $ \a ->
                shrink (a `asProxyTypeOf` proxy) `shouldSatisfy` all isValid

-- | @arbitrary@ only generates valid data
arbitraryGeneratesOnlyValid
    :: (Show a, Validity a, Arbitrary a)
    => Proxy a
    -> Property
arbitraryGeneratesOnlyValid proxy =
    forAll arbitrary $ \a ->
        (a `asProxyTypeOf` proxy) `shouldSatisfy` isValid

-- | @shrink@ only produces valid data
shrinkProducesOnlyValids
    :: (Show a, Validity a, Arbitrary a)
    => Proxy a
    -> Property
shrinkProducesOnlyValids proxy =
    forAll arbitrary $ \a ->
        shrink (a `asProxyTypeOf` proxy) `shouldSatisfy` all isValid


-- | A @Spec@ that specifies that @genValid@ only generates valid data and that
-- @genInvalid@ only generates invalid data.
--
-- In general it is a good idea to add this spec to your test suite if you
-- write a custom implementation of @genValid@ or @genInvalid@.
--
-- Example usage:
--
-- > genValiditySpec (Proxy :: Proxy MyData)
genValiditySpec
    :: (Typeable a, Show a, GenValidity a)
    => Proxy a
    -> Spec
genValiditySpec proxy = do
    let name = nameOf proxy
    describe ("GenValidity " ++ name) $ do
        describe ("genValid   :: Gen " ++ name) $
            it ("only generates valid \'" ++ name ++ "\'s") $
                genValidityValidGeneratesValid proxy

        describe ("genInvalid :: Gen " ++ name) $
            it ("only generates invalid \'" ++ name ++ "\'s") $
                genValidityInvalidGeneratesInvalid proxy

-- | @genValid@ only generates valid data
genValidityValidGeneratesValid
    :: (Show a, GenValidity a)
    => Proxy a
    -> Property
genValidityValidGeneratesValid proxy =
    forAll genValid $ \a ->
        (a `asProxyTypeOf` proxy) `shouldSatisfy` isValid

-- | @genValid@ only generates invalid data
genValidityInvalidGeneratesInvalid
    :: (Show a, GenValidity a)
    => Proxy a
    -> Property
genValidityInvalidGeneratesInvalid proxy =
    forAll genInvalid $ \a ->
        (a `asProxyTypeOf` proxy) `shouldNotSatisfy` isValid

-- | A @Spec@ that specifies that @isValidFor@ implies @isValid@
--
-- In general it is a good idea to add this spec to your test suite if
-- the @a@ in @RelativeValidity a b@ also has a @Validity@ instance.
--
-- Example usage:
--
-- > relativeValiditySpec
-- >     (Proxy :: Proxy MyDataFor)
-- >     (Proxy :: Proxy MyOtherData)
relativeValiditySpec
    :: (Typeable a, Typeable b,
        Data a, Data b,
        Show a, Show b,
        GenValidity a, GenValidity b, GenRelativeValidity a b)
    => Proxy a
    -> Proxy b
    -> Spec
relativeValiditySpec one two = do
    let nameOne = nameOf one
        nameTwo = nameOf two
    describe ("RelativeValidity " ++ nameOne ++ " " ++ nameTwo) $ do
        describe ("isValidFor :: "
                  ++ nameOne
                  ++ " -> "
                  ++ nameTwo
                  ++ " -> Bool") $ do
            it ("implies isValid " ++ nameOne ++ " for any " ++ nameTwo) $
                relativeValidityImpliesValidA one two
            it ("implies isValid " ++ nameTwo ++ " for any " ++ nameOne) $
                relativeValidityImpliesValidB one two

-- | @isValidFor a b@ implies @isValid a@ for all @b@
relativeValidityImpliesValidA
    :: (Show a, Show b,
        GenValidity a, GenValidity b, RelativeValidity a b)
    => Proxy a
    -> Proxy b
    -> Property
relativeValidityImpliesValidA one two =
    forAll genUnchecked $ \a ->
        forAll genUnchecked $ \b ->
            not ((a `asProxyTypeOf` one) `isValidFor` (b `asProxyTypeOf` two))
            || isValid a

-- | @isValidFor a b@ implies @isValid b@ for all @a@
relativeValidityImpliesValidB
    :: (Show a, Show b,
        GenValidity a, GenValidity b, RelativeValidity a b)
    => Proxy a
    -> Proxy b
    -> Property
relativeValidityImpliesValidB one two =
    forAll genUnchecked $ \a ->
        forAll genUnchecked $ \b ->
            not ((a `asProxyTypeOf` one) `isValidFor` (b `asProxyTypeOf` two))
              || isValid b


-- | A @Spec@ that specifies that @genValidFor@ and @genInvalidFor@ work as
-- intended.
--
-- In general it is a good idea to add this spec to your test suite if you
-- write a custom implementation of @genValidFor@ or @genInvalidFor@.
--
-- Example usage:
--
-- > relativeGenValiditySpec (proxy :: MyDataFor) (proxy :: MyOtherData)
genRelativeValiditySpec
    :: (Typeable a, Typeable b,
        Show a, Show b,
        GenValidity a, GenValidity b,
        RelativeValidity a b,
        GenRelativeValidity a b)
    => Proxy a
    -> Proxy b
    -> Spec
genRelativeValiditySpec one two = do
    let nameOne = nameOf one
    let nameTwo = nameOf two
    describe ("GenRelativeValidity " ++ nameOne ++ " " ++ nameTwo) $ do
        describe ("genValidFor   :: " ++ nameTwo ++ " -> Gen " ++ nameOne) $
            it ("only generates valid \'"
                ++ nameOne
                ++ "\'s for the "
                ++ nameTwo) $
                genRelativeValidityValidGeneratesValid one two

        describe ("genInvalidFor :: " ++ nameTwo ++ " -> Gen " ++ nameOne) $
            it ("only generates invalid \'"
                ++ nameOne
                ++ "\'s for the "
                ++ nameTwo) $
                genRelativeValidityInvalidGeneratesInvalid one two

-- | @genValidFor b@ only generates values that satisfy @isValidFor b@
genRelativeValidityValidGeneratesValid
    :: (Show a, Show b,
        GenValidity a, GenValidity b,
        RelativeValidity a b,
        GenRelativeValidity a b)
    => Proxy a
    -> Proxy b
    -> Property
genRelativeValidityValidGeneratesValid one two =
    forAll genValid $ \b ->
        forAll (genValidFor b) $ \a ->
            (a `asProxyTypeOf` one)
                `shouldSatisfy` (`isValidFor` (b `asProxyTypeOf` two))

-- | @genInvalidFor b@ only generates values that do not satisfy @isValidFor b@
genRelativeValidityInvalidGeneratesInvalid
    :: (Show a, Show b,
        GenValidity a, GenValidity b,
        RelativeValidity a b,
        GenRelativeValidity a b)
    => Proxy a
    -> Proxy b
    -> Property
genRelativeValidityInvalidGeneratesInvalid one two =
    forAll genUnchecked $ \b ->
        forAll (genInvalidFor b) $ \a ->
            (a `asProxyTypeOf` one)
                `shouldNotSatisfy` (`isValidFor` (b `asProxyTypeOf` two))

-- | A class of types that are the result of functions that can fail
--
-- You should not use this class yourself.
class CanFail f where
    hasFailed :: f a -> Bool
    resultIfSucceeded :: f a -> Maybe a

instance CanFail Maybe where
    hasFailed Nothing = True
    hasFailed _ = False

    resultIfSucceeded Nothing = Nothing
    resultIfSucceeded (Just r) = Just r

instance CanFail (Either e) where
    hasFailed (Left _) = True
    hasFailed _ = False

    resultIfSucceeded (Left _) = Nothing
    resultIfSucceeded (Right r) = Just r

-- | The function produces valid output when the input is generated as
-- specified by the given generator.
producesValidsOnGen
    :: (Show a, Show b, Validity b)
    => (a -> b)
    -> Gen a
    -> Property
producesValidsOnGen func gen
    = forAll gen $ \a -> func a `shouldSatisfy` isValid

-- | The function produces valid output when the input is generated by
-- @genUnchecked@
alwaysProducesValid
    :: (Show a, Show b, GenValidity a, Validity b)
    => (a -> b)
    -> Property
alwaysProducesValid = (`producesValidsOnGen` genUnchecked)

-- | The function produces valid output when the input is generated by
-- @genValid@
producesValidsOnValids
    :: (Show a, Show b, GenValidity a, Validity b)
    => (a -> b)
    -> Property
producesValidsOnValids = (`producesValidsOnGen` genValid)

producesValidsOnGens2
    :: (Show a, Show b, Show c, Validity c)
    => (a -> b -> c)
    -> Gen a -> Gen b
    -> Property
producesValidsOnGens2 func gen1 gen2
    = forAll gen1 $ \a ->
          forAll gen2 $ \b ->
              func a b `shouldSatisfy` isValid

alwaysProducesValid2
    :: (Show a, Show b, Show c, GenValidity a, GenValidity b, Validity c)
    => (a -> b -> c)
    -> Property
alwaysProducesValid2 func
    = producesValidsOnGens2 func genUnchecked genUnchecked

producesValidsOnValids2
    :: (Show a, Show b, Show c, GenValidity a, GenValidity b, Validity c)
    => (a -> b -> c)
    -> Property
producesValidsOnValids2 func
    = producesValidsOnGens2 func genValid genValid

-- | The function succeeds if the input is generated by the given generator
succeedsOnGen
    :: (Show a, Show b, Show (f b), CanFail f)
    => (a -> f b)
    -> Gen a
    -> Property
succeedsOnGen func gen
    = forAll gen $ \a -> func a `shouldNotSatisfy` hasFailed

-- | The function succeeds if the input is generated by @genValid@
succeedsOnValidInput
    :: (Show a, Show b, Show (f b), GenValidity a, CanFail f)
    => (a -> f b)
    -> Property
succeedsOnValidInput = (`succeedsOnGen` genValid)

-- | The function fails if the input is generated by the given generator
failsOnGen
    :: (Show a, Show b, Show (f b), CanFail f)
    => (a -> f b)
    -> Gen a
    -> Property
failsOnGen func gen
    = forAll gen $ \a -> func a `shouldSatisfy` hasFailed

-- | The function fails if the input is generated by @genInvalid@
failsOnInvalidInput
    :: (Show a, Show b, Show (f b), GenValidity a, CanFail f)
    => (a -> f b)
    -> Property
failsOnInvalidInput = (`failsOnGen` genInvalid)

-- | The function produces output that satisfies @isValid@ if it is given input
-- that is generated by the given generator.
validIfSucceedsOnGen
    :: (Show a, Show b, Show (f b), Validity b, CanFail f)
    => (a -> f b)
    -> Gen a
    -> Property
validIfSucceedsOnGen func gen
    = forAll gen $ \a ->
        case resultIfSucceeded (func a) of
            Nothing  -> return () -- Can happen
            Just res -> res `shouldSatisfy` isValid

-- | The function produces output that satisfies @isValid@ if it is given input
-- that is generated by @genUnchecked@.
validIfSucceeds
    :: (Show a, Show b, Show (f b), GenValidity a, Validity b, CanFail f)
    => (a -> f b)
    -> Property
validIfSucceeds = (`validIfSucceedsOnGen` genUnchecked)

succeedsOnGens2
    :: (Show a, Show b, Show c, Show (f c),
        CanFail f)
    => (a -> b -> f c)
    -> Gen a -> Gen b
    -> Property
succeedsOnGens2 func genA genB =
    forAll genA $ \a ->
        forAll genB $ \b ->
            func a b `shouldNotSatisfy` hasFailed

succeedsOnValidInput2
    :: (Show a, Show b, Show c, Show (f c),
        GenValidity a, GenValidity b,
        CanFail f)
    => (a -> b -> f c)
    -> Property
succeedsOnValidInput2 func
    = succeedsOnGens2 func genValid genValid

failsOnGens2
    :: (Show a, Show b, Show c, Show (f c),
        CanFail f)
    => (a -> b -> f c)
    -> Gen a -> Gen b
    -> Property
failsOnGens2 func genA genB =
    forAll genA $ \a ->
        forAll genB $ \b ->
            func a b `shouldSatisfy` hasFailed

failsOnInvalidInput2
    :: (Show a, Show b, Show c, Show (f c),
        GenValidity a, GenValidity b,
        CanFail f)
    => (a -> b -> f c)
    -> Property
failsOnInvalidInput2 func
    =    failsOnGens2 func genInvalid genUnchecked
    .&&. failsOnGens2 func genUnchecked genInvalid

validIfSucceedsOnGens2
    :: (Show a, Show b, Show c, Show (f c),
        Validity c, CanFail f)
    => (a -> b -> f c)
    -> Gen a -> Gen b
    -> Property
validIfSucceedsOnGens2 func genA genB =
    forAll genA $ \a ->
        forAll genB $ \b ->
            case resultIfSucceeded (func a b) of
                Nothing  -> return () -- Can happen
                Just res -> res `shouldSatisfy` isValid

validIfSucceeds2
  :: (Show a, Show b, Show c, Show (f c),
      GenValidity a, GenValidity b,
      Validity c, CanFail f)
  => (a -> b -> f c)
  -> Property
validIfSucceeds2 func
    = validIfSucceedsOnGens2 func genUnchecked genUnchecked

nameOf :: Typeable a => Proxy a -> String
nameOf proxy =
    let (_, [ty]) = splitTyConApp $ typeOf proxy
    in show ty