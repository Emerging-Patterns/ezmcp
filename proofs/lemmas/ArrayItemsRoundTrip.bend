# an array's items are the list it was built from
import Base
import ezjson@1.2.0.0/src/value.bend as Value

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
