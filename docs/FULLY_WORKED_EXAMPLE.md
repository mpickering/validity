# A full worked example

To show how to use the Validity packages, here is a contrived example that works through the entire thought process:

Suppose we want to write a prime factorisation function:

``` Haskell
primeFactorisation :: Int -> [Int]
```

Input-output examples include the following:

```
2 -> [2]
4 -> [2, 2]
30 -> [2, 3, 5]
```

The problem at hand is well-defined, and it immediately becomes clear that `Int` and `[Int]` are not the best input- and output types for this function.
A prime factorisation is only defined for integers greater than one, and a prime factorisation is a non-empty list of primes.
If we consider all possible values of the input- and output types, there is a lot that can go wrong with this function.

Using static analysis to prove the correctness of this function has two problems.
First there is no mention of the proven properties in the type-system.
Secondly, this is most likely very expensive and probably not even decidable.

Instead we turn to testing.
We will test the function thoroughly to make sure that it works when we implement it, and that it keeps working when we optimise it later.
The solution that we use will also ensure that there is a mention of these tested properties in the type system.

We start by defining some `newtype` wrappers that encapsulate the type on which we want to impose further invariants:

``` Haskell
newtype HasPrimeFactorisation
  -- INVARIANT: (> 0}
  = HasPrimeFactorisation Int

newtype Prime
  -- INVARIANT: isPrime, assuming isPrime :: Int -> Bool is defined
  = Prime Int

newtype PrimeFactorisation
  -- INVARIANT: the contained 'Prime' values are valid.
  = PrimeFactorisation [Prime]
```

Here we have written the invariants in comments.

## Part 1: Explicit invariants
We can now write functions like these to make the invariants explicit.
Note that the invariants are inherent to the type.
This is where the `validity` package comes in.
It provides a type class `Validity` that allows us to make the invariants explicit:

``` Haskell
instance Validity HasPrimeFactorisation where
    validate (HasPrimeFactorisation i) = check (i > 0) "the contained integer is greater than 0"

instance Validity Prime where
    validate (Prime i) = check (isPrime i) "the contained integer is a prime"

instance Validity PrimeFactorisation where
    validate (PrimeFactorisation ps) = mconcat
        [ check (not (null ps)) "there is at least one prime
        , annotate ps "the contained primes"
        ]
```

Note that in the last instantiation, we used the built-in `instance Validity a => Validity [a]` which requires that all elements of `ps` are valid.


## Part 2: Validity-based testing

Now that we have types that instantiate the `Validity` type class, we have to decide what the type of `primeFactorisation` should be.
If we leave the constructor of `HasPrimeFactorisation` exposed, we have to reflect the possibility of failure in the type, in order to be safe:

``` Haskell
primeFactorisation :: HasPrimeFactorisation -> Maybe PrimeFactorisation
```

We can then write some sanity tests as follows:

``` Haskell
describe "primeFactorisation" $ do
  it "fails on invalid input" $ do
    forAll (arbitrary `suchThat` isInvalid) $ \h ->
      primeFactorisation h `shouldBe` Nothing

  it "succeeds on valid input input" $ do
    forAll (arbitrary `suchThat` isValid) $ \h ->
      primeFactorisation h `shouldSatisfy` isJust

  it "produces valid output when it succeeds" $ do
    forAll arbitrary $ \h ->
      case primeFactorisation h of
        Nothing -> return ()
        Just pf -> pf `shouldSatisfy` isValid
```

Instead, we can also not export the constructor of `HasPrimeFactorisation` and write `primeFactorisation` with the assumption that it will only be given valid `HasPrimeFactorisation`s.
This assumption is less safe, but if the risk is contained in the module (by not exporting the constructor and instead exporting a smart constructor that can fail `hasPrimeFactorisation :: Int -> Maybe HasPrimeFactorisation`), then it may be worth trading it for a simpler type.

``` Haskell
primeFactorisation :: HasPrimeFactorisation -> PrimeFactorisation
```

The tests also become easier this way.
Now we only need one sanity test.
The other tests are now tests for the smart constructor instead.

``` Haskell
describe "primeFactorisation" $ do
  it "produces valid output when given valid input" $ do
    forAll (arbitrary `suchThat` isValid) $ \h ->
      case primeFactorisation h of
        Nothing -> return ()
        Just pf -> pf `shouldSatisfy` isValid
```

## Part 3: Simplifying and speeding up generators for validity-based testing

Only about half of the possible values of the type `HasPrimeFactorisation` are valid values.
This means that when we use the `suchThat` function to build a generator of valid values, it has to retry generating a valid value more than half of the time it is used.
This effect is much worse still for types that don't have a lot of valid values, or for which the `isValid` function is expensive to compute.

This is where the, `GenUnchecked`, `GenValid` and `GenInvalid` type classes from the `genvalidity` package comes in.
It allows us to specify how to generate valid or invalid values of a given type that instantiates `Validity`.

``` Haskell
genUnchecked :: GenUnchecked a => Gen a
genValid :: GenValid a => Gen a
genInvalid :: GenInvalid a => Gen a
``` 

An instantiation of `GenUnchecked` can be generated using `Generic` or written manually: 

``` Haskell
instance GenUnchecked HasPrimeFactorisation where
    genUnchecked = HasPrimeFactorisation <$> arbitrary
```

`GenValid` and `GenInvalid` have default implementations using `suchThat`.

``` Haskell
instance GenValid HasPrimeFactorisation
instance GenInvalid HasPrimeFactorisation
```

However, the internals of `genValid` will often first generate an value, check whether if it is valid and try again if not.
Because of this inefficiency, we can now implement a faster version of `genValid`:

``` Haskell
instance GenValid HasPrimeFactorisation where
    genValid = (HasPrimeFactorisation . (+1) . abs) <$> arbitrary
```

The tests that we wrote earlier can now be simplified:

``` Haskell
describe "primeFactorisation" $ 
  it "produces valid output when given valid input" $
    forAll genValid $ \h ->
      case primeFactorisation h of
        Nothing -> return ()
        Just pf -> pf `shouldSatisfy` isValid
```

## Part 4: Generalized validity-based testing

`Validity`, `GenUnchecked`, `GenValid` and `GenInvalid` together provide a framework that is powerful enough to abstract away most of the boiler-plate testing code into property-generating combinators.

The above example test can be rewritten using the `genvalidity-hspec` package:

``` Haskell
describe "primeFactorisation" $ do
  it "produces valid output when given valid input" $ do
    producesValidsOnValids primeFactorisation
```

In fact, the `genvalidity-hspec` library contains a huge amount of property-generating combinators.
Similar to the `producesValidsOnValids` function, there exists an `equivalentOnValid` function that could be used as follows:


``` Haskell
describe "primeFactorisation" $
  it "is trivial for primes" $
    equivalentOnGen
      primeFactorisation
      (\(HasPrimeFactorisation i) -> [Prime i]) 
      (HasPrimeFactorisation <$> (arbitrary `suchThat` isPrime))
```

This specifies that, for every prime `HasPrimeFactorisation`, the result of `primeFactorisation` should be a list with only that element.

This concludes a full worked example of validity, validity based testing, efficient validity-based testing and generalized validity-based testing.
