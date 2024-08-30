{
  __functor = _: { context, test, type, ... }: test {
    inherit context type;
  };
}
