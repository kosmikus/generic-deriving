{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE CPP #-}

module Generics.Deriving.Base (
  -- * Introduction
  --
  -- |
  --
  -- Datatype-generic functions are are based on the idea of converting values of
  -- a datatype 'T' into corresponding values of a (nearly) isomorphic type 'Rep T'.
  -- The type 'Rep T' is
  -- built from a limited set of type constructors, all provided by this module. A
  -- datatype-generic function is then an overloaded function with instances
  -- for most of these type constructors, together with a wrapper that performs
  -- the mapping between 'T' and 'Rep T'. By using this technique, we merely need
  -- a few generic instances in order to implement functionality that works for any
  -- representable type.
  --
  -- Representable types are collected in the 'Generic' class, which defines the
  -- associated type 'Rep' as well as conversion functions 'from' and 'to'.
  -- Typically, you will not define 'Generic' instances by hand, but have the compiler
  -- derive them for you.

  -- ** Representing datatypes
  --
  -- |
  --
  -- The key to defining your own datatype-generic functions is to understand how to
  -- represent datatypes using the given set of type constructors.
  --
  -- Let us look at an example first:
  --
  -- > data Tree a = Leaf a | Node (Tree a) (Tree a)
  -- >   deriving Generic1
  --
  -- The above declaration causes the following representation to be generated:
  --
  -- > class Generic (Tree a) where
  -- >   type Rep (Tree a) =
  -- >     D1 D1Tree
  -- >       (C1 C1_0Tree
  -- >          (S1 NoSelector (Par0 a))
  -- >        :+:
  -- >        C1 C1_1Tree
  -- >          (S1 NoSelector (Rec0 (Tree a))
  -- >           :*:
  -- >           S1 NoSelector (Rec0 (Tree a))))
  -- >   ...
  --
  -- /HINT:/ You can obtain information about the code being generated from GHC by passing
  -- the @-ddump-deriv@ flag. In GHCi, you can expand a type family such as 'Rep' using
  -- the @:kind!@ command.
  --
  -- /TODO:/ Newer GHC versions abandon the distinction between 'Par0' and 'Rec0' and will
  -- use 'Rec0' everywhere.
  --
  -- This is a lot of information! However, most of it is actually merely meta-information
  -- that makes names of datatypes and constructors and more available on the type level.
  --
  -- Here is a reduced representation for 'Tree' with nearly all meta-information removed,
  -- for now keeping only the most essential aspects:
  --
  -- > instance Generic (Tree a) where
  -- >   type Rep (Tree a) =
  -- >     Par0 a
  -- >     :+:
  -- >     (Rec0 (Tree a) :*: Rec0 (Tree a))
  --
  -- The 'Tree' datatype has two constructors. The representation of individual constructors
  -- is combined using the binary type constructor ':+:'.
  --
  -- The first constructor consists of a single field, which is the parameter 'a'. This is
  -- represented as 'Par0 a'.
  --
  -- The second constructor consists of two fields. Each is a recursive field of type @Tree a@,
  -- represented as @Rec0 (Tree a)@. Representations of individual fields are combined using
  -- the binary type constructor ':*:'.
  --
  -- Now let us explain the additional tags being used in the complete representation:
  --
  --    * The @S1 NoSelector@ indicates that there is no record field selector associated with
  --      this field of the constructor.
  --
  --    * The @C1 C1_0Tree@ and @C1 C1_1Tree@ invocations indicate that the enclosed part is
  --      the representation of the first and second constructor of datatype 'Tree', respectively.
  --      Here, 'C1_0Tree' and 'C1_1Tree' are datatypes generated by the compiler as part of
  --      @deriving Generic@. These datatypes are proxy types with no values. They are useful
  --      because they are instances of the type class 'Constructor'. This type class can be used
  --      to obtain information about the constructor in question, such as its name
  --      or infix priority.
  --
  --    * The @D1 D1Tree@ tag indicates that the enclosed part is the representation of the
  --      datatype 'Tree'. Again, 'D1Tree' is a datatype generated by the compiler. It is a
  --      proxy type, and is useful by being an instance of class 'Datatype', which
  --      can be used to obtain the name of a datatype, the module it has been defined in, and
  --      whether it has been defined using 'data' or 'newtype'.

  -- ** Derived and fundamental representation types
  --
  -- |
  --
  -- There are many datatype-generic functions that do not distinguish between positions that
  -- are parameters or positions that are recursive calls. There are also many datatype-generic
  -- functions that do not care about the names of datatypes and constructors at all. To keep
  -- the number of cases to consider in generic functions in such a situation to a minimum,
  -- it turns out that many of the type constructors introduced above are actually synonyms,
  -- defining them to be variants of a smaller set of constructors.

  -- *** Individual fields of constructors: 'K1'
  --
  -- |
  --
  -- The type constructors 'Par0' and 'Rec0' are variants of 'K1':
  --
  -- > type Par0 = K1 P
  -- > type Rec0 = K1 R
  --
  -- Here, 'P' and 'R' are type-level proxies again that do not have any associated values.

  -- *** Meta information: 'M1'
  --
  -- |
  --
  -- The type constructors 'S1', 'C1' and 'D1' are all variants of 'M1':
  --
  -- > type S1 = M1 S
  -- > type C1 = M1 C
  -- > type D1 = M1 D
  --
  -- The types 'S', 'C' and 'R' are once again type-level proxies, just used to create
  -- several variants of 'M1'.

  -- *** Additional generic representation type constructors
  --
  -- |
  --
  -- Next to 'K1', 'M1', ':+:' and ':*:' there are a few more type constructors that occur
  -- in the representations of other datatypes.

  -- **** Empty datatypes: 'V1'
  --
  -- |
  --
  -- For empty datatypes, 'V1' is used as a representation. For example,
  --
  -- > data Empty deriving Generic
  --
  -- yields
  --
  -- > instance Generic Empty where
  -- >   type Rep Empty = D1 D1Empty V1

  -- **** Constructors without fields: 'U1'
  --
  -- |
  --
  -- If a constructor has no arguments, then 'U1' is used as its representation. For example
  -- the representation of 'Bool' is
  --
  -- > instance Generic Bool where
  -- >   type Rep Bool =
  -- >     D1 D1Bool
  -- >       (C1 C1_0Bool U1 :+: C1 C1_1Bool U1)

  -- *** Representation of types with many constructors or many fields
  --
  -- |
  --
  -- As ':+:' and ':*:' are just binary operators, one might ask what happens if the
  -- datatype has more than two constructors, or a constructor with more than two
  -- fields. The answer is simple: the operators are used several times, to combine
  -- all the constructors and fields as needed. However, users /should not rely on
  -- a specific nesting strategy/ for ':+:' and ':*:' being used. The compiler is
  -- free to choose any nesting it prefers. (In practice, the current implementation
  -- tries to produce a more or less balanced nesting, so that the traversal of the
  -- structure of the datatype from the root to a particular component can be performed
  -- in logarithmic rather than linear time.)

  -- ** Defining datatype-generic functions
  --
  -- |
  --
  -- A datatype-generic function comprises two parts:
  --
  --    1. /Generic instances/ for the function, implementing it for most of the representation
  --       type constructors introduced above.
  --
  --    2. A /wrapper/ that for any datatype that is in `Generic`, performs the conversion
  --       between the original value and its `Rep`-based representation and then invokes the
  --       generic instances.
  --
  -- As an example, let us look at a function 'encode' that produces a naive, but lossless
  -- bit encoding of values of various datatypes. So we are aiming to define a function
  --
  -- > encode :: Generic a => a -> [Bool]
  --
  -- where we use 'Bool' as our datatype for bits.
  --
  -- For part 1, we define a class 'Encode''. Perhaps surprisingly, this class is parameterized
  -- over a type constructor 'f' of kind @* -> *@. This is a technicality: all the representation
  -- type constructors operate with kind @* -> *@ as base kind. But the type argument is never
  -- being used. This may be changed at some point in the future. The class has a single method,
  -- and we use the type we want our final function to have, but we replace the occurrences of
  -- the generic type argument 'a' with 'f p' (where the 'p' is any argument; it will not be used).
  --
  -- > class Encode' f where
  -- >   encode' :: f p -> [Bool]
  --
  -- With the goal in mind to make 'encode' work on 'Tree' and other datatypes, we now define
  -- instances for the representation type constructors 'V1', 'U1', ':+:', ':*:', 'K1', and 'M1'.

  -- *** Definition of the generic representation types
  --
  -- |
  --
  -- In order to be able to do this, we need to know the actual definitions of these types:
  --
  -- > data    V1        p                       -- lifted version of 'Empty'
  -- > data    U1        p = U1                  -- lifted version of '()'
  -- > data    (:+:) f g p = L1 (f p) | R1 (g p) -- lifted version of 'Either'
  -- > data    (:*:) f g p = (f p) :*: (g p)     -- lifted version of '(,)' 
  -- > newtype K1    i c p = K1 { unK1 :: c }    -- a container for a 'c'
  -- > newtype M1  i t f p = M1 { unM1 :: f p }  -- a wrapper
  --
  -- So, 'U1' is just the unit type, ':+:' is just a binary choice like 'Either',
  -- ':*:' is a binary pair like the pair constructor '(,)', and 'K1' is a value
  -- of a specific type 'c', and 'M1' wraps a value of the generic type argument,
  -- which in the lifted world is an 'f p' (where we do not care about 'p').

  -- *** Generic instances
  --
  -- |
  --
  -- The instance for 'V1' is slightly awkward (but also rarely used):
  --
  -- > instance Encode' V1 where
  -- >   encode' x = error "impossible"
  --
  -- There are no values of type @V1 p@ to pass (except undefined), so this is
  -- actually impossible. One can ask why it is useful to define an instance for
  -- 'V1' at all in this case? Well, an empty type can be used as an argument to
  -- a non-empty type, and you might still want to encode the resulting type.
  -- As a somewhat contrived example, consider @[Empty]@, which is not an empty
  -- type, but contains just the empty list. The @V1@ instance ensures that we
  -- can call the generic function on such types.
  --
  -- There is exactly one value of type 'U1', so encoding it requires no
  -- knowledge, and we can use zero bits:
  --
  -- > instance Encode' U1 where
  -- >   encode' U1 = []
  --
  -- In the case for ':+:', we produce 'False' or 'True' depending on whether
  -- the constructor of the value provided is located on the left or on the right:
  --
  -- > instance (Encode' f, Encode' g) => Encode' (f :+: g) where
  -- >   encode' (L1 x) = False : encode' x
  -- >   encode' (R1 x) = True  : encode' x
  --
  -- In the case for ':*:', we append the encodings of the two subcomponents:
  --
  -- > instance (Encode' f, Encode' g) => Encode' (f :*: g) where
  -- >   encode' (x :*: y) = encode' x ++ encode' y
  --
  -- The case for 'K1' is rather interesting. Here, we call the final function
  -- 'encode' that we yet have to define, recursively. We will use another type
  -- class 'Encode' for that function:
  --
  -- > instance (Encode c) => Encode' (K1 i c) where
  -- >   encode' (K1 x) = encode x
  --
  -- Note how 'Par0' and 'Rec0' both being mapped to 'K1' allows us to define
  -- a uniform instance here.
  --
  -- Similarly, we can define a uniform instance for 'M1', because we completely
  -- disregard all meta-information:
  --
  -- > instance (Encode' f) => Encode' (M1 i t f) where
  -- >   encode' (M1 x) = encode' x
  --
  -- Unlike in 'K1', the instance for 'M1' refers to 'encode'', not 'encode'.

  -- *** The wrapper and generic default
  --
  -- |
  --
  -- We now define class 'Encode' for the actual 'encode' function:
  --
  -- > class Encode a where
  -- >   encode :: a -> [Bool]
  -- >   default encode :: (Generic a) => a -> [Bool]
  -- >   encode x = encode' (from x)
  --
  -- The incoming 'x' is converted using 'from', then we dispatch to the
  -- generic instances using 'encode''. We use this as a default definition
  -- for 'encode'. We need the 'default encode' signature because ordinary
  -- Haskell default methods must not introduce additional class constraints,
  -- but our generic default does.
  --
  -- Defining a particular instance is now as simple as saying
  --
  -- > instance (Encode a) => Encode (Tree a)
  --
  -- /TODO:/ Add usage example?
  --
  -- The generic default is being used. In the future, it will hopefully be
  -- possible to use @deriving Encode@ as well, but GHC does not yet support
  -- that syntax for this situation.
  --
  -- Having 'Encode' as a class has the advantage that we can define
  -- non-generic special cases, which is particularly useful for abstract
  -- datatypes that have no structural representation. For example, given
  -- a suitable integer encoding function 'encodeInt', we can define
  --
  -- > instance Encode Int where
  -- >   encode = encodeInt

  -- ** Generic constructor classes
  --
  -- |
  --
  -- Datatype-generic functions as defined above work for a large class
  -- of datatypes, including parameterized datatypes. (We have used 'Tree'
  -- as our example above, which is of kind @* -> *@.) However, the
  -- 'Generic' class ranges over types of kind @*@, and therefore, the
  -- resulting generic functions (such as 'encode') must be parameterized
  -- by a generic type argument of kind @*@.
  --
  -- What if we want to define generic classes that range over type
  -- constructors (such as 'Functor', 'Traversable', or 'Foldable')?

  -- *** The 'Generic1' class
  --
  -- |
  --
  -- Like 'Generic', there is a class 'Generic1' that defines a
  -- representation 'Rep1' and conversion functions 'from1' and 'to1',
  -- only that 'Generic1' ranges over types of kind @* -> *@.
  -- The 'Generic1' class is also derivable.
  --
  -- The representation 'Rep1' is ever so slightly different from 'Rep'.
  -- Let us look at 'Tree' as an example again:
  --
  -- > data Tree a = Leaf a | Node (Tree a) (Tree a)
  -- >   deriving (Generic1)
  --
  -- The above declaration causes the following representation to be generated:
  --
  -- > class Generic1 Tree where
  -- >   type Rep1 Tree =
  -- >     D1 D1Tree
  -- >       (C1 C1_0Tree
  -- >          (S1 NoSelector Par1)
  -- >        :+:
  -- >        C1 C1_1Tree
  -- >          (S1 NoSelector (Rec1 Tree)
  -- >           :*:
  -- >           S1 NoSelector (Rec1 Tree)))
  -- >   ...
  --
  -- The representation reuses 'D1', 'C1', 'S1' (and thereby 'M1') as well
  -- as ':+:' and ':*:' from 'Rep'. (This reusability is the reason that we
  -- carry around the dummy type argument for kind-@*@-types, but there are
  -- already enough different names involved without duplicating each of
  -- these.)
  --
  -- What's different is that we now use 'Par1' to refer to the parameter
  -- (and that parameter, which used to be 'a'), is not mentioned explicitly
  -- by name anywhere; and we use 'Rec1' to refer to a recursive use of @Tree a@.

  -- *** Representation of @* -> *@ types
  --
  -- |
  --
  -- Unlike 'Par0' and 'Rec0', the 'Par1' and 'Rec1' type constructors do not
  -- map to 'K1'. They are defined directly, as follows:
  --
  -- > newtype Par1   p = Par1 { unPar1 ::   p } -- gives access to parameter 'p'
  -- > newtype Rec1 f p = Rec1 { unRec1 :: f p } -- a wrapper
  --
  -- In 'Par1', the parameter 'p' is used for the first time, whereas 'Rec1' simply
  -- wraps an application of 'f' to 'p'.
  --
  -- Note that 'K1' (in the guise of 'Rec0') can still occur in a 'Rep1' representation,
  -- namely when the datatype has a field that does not mention the parameter.
  --
  -- The declaration
  --
  -- > data WithInt a = WithInt Int a
  -- >   deriving (Generic1)
  --
  -- yields
  --
  -- > class Rep1 WithInt where
  -- >   type Rep1 WithInt =
  -- >     D1 D1WithInt
  -- >       (C1 C1_0WithInt
  -- >         (S1 NoSelector (Rec0 Int)
  -- >          :*:
  -- >          S1 NoSelector Par1))
  --
  -- If the parameter 'a' appears underneath a composition of other type constructors,
  -- then the representation involves composition, too:
  --
  -- > data Rose a = Fork a [Rose a]
  --
  -- yields
  --
  -- > class Rep1 Rose where
  -- >   type Rep1 Rose =
  -- >     D1 D1Rose
  -- >       (C1 C1_0Rose
  -- >         (S1 NoSelector Par1
  -- >          :*:
  -- >          S1 NoSelector ([] :.: Rec1 Rose)
  --
  -- where
  --
  -- > newtype (:.:) f g p = Comp1 { unComp1 :: f (g p) }

  -- *** Limitations
  --
  -- |
  --
  -- /TODO/
  --
  -- /TODO:/ Also clear up confusion about 'Rec0' and 'Rec1' not really indicating recursion.

  -- * Generic representation types
    V1, U1(..), Par1(..), Rec1(..), K1(..), M1(..)
  , (:+:)(..), (:*:)(..), (:.:)(..)

  -- ** Synonyms for convenience
  , Rec0, Par0, R, P
  , D1, C1, S1, D, C, S

  -- * Meta-information
  , Datatype(..), Constructor(..), Selector(..), NoSelector
  , Fixity(..), Associativity(..), Arity(..), prec

  -- * Generic type classes
  , Generic(..), Generic1(..)

  ,
  ) where


#if __GLASGOW_HASKELL__ >= 701
import GHC.Generics

#else
--------------------------------------------------------------------------------
-- Representation types
--------------------------------------------------------------------------------

-- | Void: used for datatypes without constructors
data V1 p

-- | Unit: used for constructors without arguments
data U1 p = U1

-- | Used for marking occurrences of the parameter
newtype Par1 p = Par1 { unPar1 :: p }


-- | Recursive calls of kind * -> *
newtype Rec1 f p = Rec1 { unRec1 :: f p }

-- | Constants, additional parameters and recursion of kind *
newtype K1 i c p = K1 { unK1 :: c }

-- | Meta-information (constructor names, etc.)
newtype M1 i c f p = M1 { unM1 :: f p }

-- | Sums: encode choice between constructors
infixr 5 :+:
data (:+:) f g p = L1 { unL1 :: f p } | R1 { unR1 :: g p }

-- | Products: encode multiple arguments to constructors
infixr 6 :*:
data (:*:) f g p = f p :*: g p

-- | Composition of functors
infixr 7 :.:
newtype (:.:) f g p = Comp1 { unComp1 :: f (g p) }

-- | Tag for K1: recursion (of kind *)
data R
-- | Tag for K1: parameters (other than the last)
data P

-- | Type synonym for encoding recursion (of kind *)
type Rec0  = K1 R
-- | Type synonym for encoding parameters (other than the last)
type Par0  = K1 P

-- | Tag for M1: datatype
data D
-- | Tag for M1: constructor
data C
-- | Tag for M1: record selector
data S

-- | Type synonym for encoding meta-information for datatypes
type D1 = M1 D

-- | Type synonym for encoding meta-information for constructors
type C1 = M1 C

-- | Type synonym for encoding meta-information for record selectors
type S1 = M1 S

-- | Class for datatypes that represent datatypes
class Datatype d where
  -- | The name of the datatype, fully qualified
  datatypeName :: t d (f :: * -> *) a -> String
  moduleName   :: t d (f :: * -> *) a -> String

-- | Class for datatypes that represent records
class Selector s where
  -- | The name of the selector
  selName :: t s (f :: * -> *) a -> String

-- | Used for constructor fields without a name
data NoSelector

instance Selector NoSelector where selName _ = ""

-- | Class for datatypes that represent data constructors
class Constructor c where
  -- | The name of the constructor
  conName :: t c (f :: * -> *) a -> String

  -- | The fixity of the constructor
  conFixity :: t c (f :: * -> *) a -> Fixity
  conFixity = const Prefix

  -- | Marks if this constructor is a record
  conIsRecord :: t c (f :: * -> *) a -> Bool
  conIsRecord = const False


-- | Datatype to represent the arity of a tuple.
data Arity = NoArity | Arity Int
  deriving (Eq, Show, Ord, Read)

-- | Datatype to represent the fixity of a constructor. An infix
-- | declaration directly corresponds to an application of 'Infix'.
data Fixity = Prefix | Infix Associativity Int
  deriving (Eq, Show, Ord, Read)

-- | Get the precedence of a fixity value.
prec :: Fixity -> Int
prec Prefix      = 10
prec (Infix _ n) = n

-- | Datatype to represent the associativy of a constructor
data Associativity =  LeftAssociative 
                   |  RightAssociative
                   |  NotAssociative
  deriving (Eq, Show, Ord, Read)

-- | Representable types of kind *
class Generic a where
  type Rep a :: * -> *
  -- | Convert from the datatype to its representation
  from  :: a -> Rep a x
  -- | Convert from the representation to the datatype
  to    :: Rep a x -> a

-- | Representable types of kind * -> *
class Generic1 f where
  type Rep1 f :: * -> *
  -- | Convert from the datatype to its representation
  from1  :: f a -> Rep1 f a
  -- | Convert from the representation to the datatype
  to1    :: Rep1 f a -> f a

#endif
