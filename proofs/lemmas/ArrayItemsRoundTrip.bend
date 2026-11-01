# an array's items are the list it was built from
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value

# an array's items are the list it was built from
def eq.items_arr(
  xs: List<&2, Value.Json>
) -> {Value.items.go(Value.arr.go(xs)) == xs : List<&2, Value.Json>}:
  match xs:
    case []:
      {==}
    case h <> t:
      Equal.cong(List<&2, Value.Json>, List<&2, Value.Json>, r => h <> r,
        Value.items.go(Value.arr.go(t)), t, eq.items_arr(t))
