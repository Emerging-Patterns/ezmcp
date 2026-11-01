# Bool, Char and String facts, and anything from False == True
import Base

def bit.emp(b: Bool) -> Type:
  match b:
    case False{}:
      Unit
    case True{}:
      Empty

def bit.clash(e: {False{} == True{} : Bool}) -> Empty:
  %e : bit.emp(_)
  Unit{}

def bit.gone(a, -A: Kind(a), e: Empty) -> A:
  match e:

# anything follows from False == True
def absurd(a, -A: Kind(a), e: {False{} == True{} : Bool}) -> A:
  bit.gone(a, A, bit.clash(e))
